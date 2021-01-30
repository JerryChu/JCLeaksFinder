/**
 * Tencent is pleased to support the open source community by making MLeaksFinder available.
 *
 * Copyright (C) 2017 THL A29 Limited, a Tencent company. All rights reserved.
 *
 * Licensed under the BSD 3-Clause License (the "License"); you may not use this file except in compliance with the License. You may obtain a copy of the License at
 *
 * https://opensource.org/licenses/BSD-3-Clause
 *
 * Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the specific language governing permissions and limitations under the License.
 */

#import "MLeakedObjectProxy.h"
#import "MLeaksFinder.h"
#import "NSObject+MemoryLeak.h"
#import <objc/runtime.h>
#import <UIKit/UIKit.h>
#import <FBRetainCycleDetector/FBRetainCycleDetector.h>
#import "JCLeaksConfig.h"
#import "JCGlobalObjectsFinder.h"

static NSMutableSet *leakedObjectPtrs;

@interface MLeakedObjectProxy ()<UIAlertViewDelegate>
@property (nonatomic, weak) id object;
@property (nonatomic, strong) NSNumber *objectPtr;
@property (nonatomic, strong) NSArray *viewStack;
@end

@implementation MLeakedObjectProxy

+ (BOOL)isAnyObjectLeakedAtPtrs:(NSSet *)ptrs {
    NSAssert([NSThread isMainThread], @"Must be in main thread.");
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        leakedObjectPtrs = [[NSMutableSet alloc] init];
    });
    
    if (!ptrs.count) {
        return NO;
    }
    if ([leakedObjectPtrs intersectsSet:ptrs]) {
        return YES;
    } else {
        return NO;
    }
}

+ (void)addLeakedObject:(id)object {
    NSAssert([NSThread isMainThread], @"Must be in main thread.");
    
    MLeakedObjectProxy *proxy = [[MLeakedObjectProxy alloc] init];
    proxy.object = object;
    proxy.objectPtr = @((uintptr_t)object);
    proxy.viewStack = [object JC_viewStack];
    static const void *const kLeakedObjectProxyKey = &kLeakedObjectProxyKey;
    objc_setAssociatedObject(object, kLeakedObjectProxyKey, proxy, OBJC_ASSOCIATION_RETAIN);
    
    [leakedObjectPtrs addObject:proxy.objectPtr];

    [self p_notifyWithLeakedObject:object viewStack:proxy.viewStack];
}

- (void)dealloc {
    NSNumber *objectPtr = _objectPtr;
    NSArray *viewStack = _viewStack;
    dispatch_async(dispatch_get_main_queue(), ^{
        [leakedObjectPtrs removeObject:objectPtr];
        NSLog(@"Object Deallocated :%@",[NSString stringWithFormat:@"%@", viewStack]);
    });
}

#pragma mark - alert

+ (void)p_notifyWithLeakedObject:(NSObject *)leakedObject viewStack:(NSArray<NSString *> *)viewStack {
    FBRetainCycleDetector *detector = [FBRetainCycleDetector new];
    [detector addCandidate:leakedObject];
    NSSet *result = [detector findRetainCyclesWithMaxCycleLength:[JCLeaksConfig sharedInstance].retainCycleMaxLength];
    if (result.count > 0 || ![JCLeaksConfig sharedInstance].checkGlobalRetain) {
        // 找到循环引用链
        [self p_callbackWithLeakedObject:leakedObject retainInfo:result viewStack:viewStack];
    } else {
        // 未找到循环引用链，尝试检测是否被全局对象持有
        [self p_checkGlobalObjects:leakedObject viewStack:viewStack];
    }
}

+ (void)p_checkGlobalObjects:(NSObject *)leakedObject viewStack:(NSArray<NSString *> *)viewStack {
    // 全局对象检测耗时较长（3s左右），放到后台线程执行
    static dispatch_queue_t queue = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        queue = dispatch_queue_create("jc_leaks_queue", DISPATCH_QUEUE_SERIAL);
    });
//    dispatch_async(queue, ^{
        NSArray<NSObject *> *globalObjects = [[self p_globalObjects] arrayByAddingObjectsFromArray:[JCLeaksConfig sharedInstance].extraGlobalObjects];
        // 如果leakedObject被全局对象持有，那么实际不存在循环引用链。这里人工设置associatedObject造成循环引用，以便被detector检测到。
        NSString *fakeAssociationKey = @"jc_leak_fake_%p";
        for (NSObject *obj in globalObjects) {
            objc_setAssociatedObject(leakedObject, [NSString stringWithFormat:fakeAssociationKey, obj].UTF8String, obj, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }

        // 开始检测，并过滤无用数据
        FBRetainCycleDetector *detector = [FBRetainCycleDetector new];
        [detector addCandidate:leakedObject];
        NSSet *result = [detector findRetainCyclesWithMaxCycleLength:[JCLeaksConfig sharedInstance].globalRetainMaxLength];
        NSMutableSet *retainCycles = [NSMutableSet setWithCapacity:1];
        [result enumerateObjectsUsingBlock:^(id  _Nonnull obj, BOOL * _Nonnull stop) {
            __block BOOL valid = NO;
            [(NSArray *)obj enumerateObjectsUsingBlock:^(id  _Nonnull item, NSUInteger idx, BOOL * _Nonnull stop) {
                // 全局对象本身可能就有循环引用，由于“全局对象”一般不会被销毁，因此不算作内存泄漏
                // 过滤出包含leakedObject的引用链
                if ([item isKindOfClass:[FBObjectiveCObject class]] && ((FBObjectiveCObject *)item).object == leakedObject) {
                    valid = YES;
                    *stop = YES;
                }
            }];
            if (valid) {
                [retainCycles addObject:obj];
            }
        }];

        // 移除人工设置的associatedObject
        for (NSObject *obj in globalObjects) {
            objc_setAssociatedObject(leakedObject, [NSString stringWithFormat:fakeAssociationKey, obj].UTF8String, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }

        // 将人工添加的对全局对象的associateObject修改为[Global]标识符
        for (NSArray<FBObjectiveCGraphElement *> *cycle in retainCycles) {
            for (FBObjectiveCGraphElement *element in cycle) {
                if ([globalObjects containsObject:element.object]) {
                    [element setValue:@[@"[Global]"] forKey:@"namePath"];
                }
            }
        }

        [self p_callbackWithLeakedObject:leakedObject retainInfo:retainCycles viewStack:viewStack];
//    });
}

+ (NSArray<NSObject *> *)p_globalObjects {
    NSMutableArray<NSObject *> *globalObjects = [NSMutableArray array];

    [[JCGlobalObjectsFinder globalObjects] enumerateObjectsUsingBlock:^(NSObject * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        if ([obj isKindOfClass:[NSArray class]]
            && ![obj isKindOfClass:[NSString class]]
            && ![obj isKindOfClass:[NSValue class]]
            && ![obj isKindOfClass:[NSData class]]) {
            [globalObjects addObject:obj];
        }
    }];

    return [globalObjects copy];
}

+ (void)p_callbackWithLeakedObject:(NSObject *)object retainInfo:(NSSet *)retainInfo viewStack:(NSArray<NSString *> *)viewStack {
    if ([JCLeaksConfig sharedInstance].callback) {
        [JCLeaksConfig sharedInstance].callback(object, retainInfo, viewStack);
    }
}

@end
