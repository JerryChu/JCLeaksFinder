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

#import "NSObject+MemoryLeak.h"
#import "MLeakedObjectProxy.h"
#import "MLeaksFinder.h"
#import <objc/runtime.h>
#import <UIKit/UIKit.h>
#import "JCLeaksConfig.h"

static const void *const kViewStackKey = &kViewStackKey;
static const void *const kParentPtrsKey = &kParentPtrsKey;
const void *const kLatestSenderKey = &kLatestSenderKey;
const void *const kRefuseCheckKey = &kRefuseCheckKey;

@implementation NSObject (MemoryLeak)

- (void)JC_markAsWhiteLeakedObject {
    objc_setAssociatedObject(self, kRefuseCheckKey, @(YES), OBJC_ASSOCIATION_RETAIN);
}

- (BOOL)JC_willDealloc {
    NSString *className = NSStringFromClass([self class]);
    if ([[NSObject JC_classNamesWhitelist] containsObject:className]) {
        return NO;
    }
    
    NSNumber *senderPtr = objc_getAssociatedObject([UIApplication sharedApplication], kLatestSenderKey);
    if ([senderPtr isEqualToNumber:@((uintptr_t)self)]) {
        return NO;
    }
    
    if ([objc_getAssociatedObject(self, kRefuseCheckKey) boolValue]) {
        return NO;
    }
    
    __weak id weakSelf = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)([JCLeaksConfig sharedInstance].detectThresholdInSeconds * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        __strong id strongSelf = weakSelf;
        [strongSelf JC_assertNotDealloc];
    });
    
    return YES;
}

- (void)JC_assertNotDealloc {
    if ([MLeakedObjectProxy isAnyObjectLeakedAtPtrs:[self JC_parentPtrs]]) {
        return;
    }
    [MLeakedObjectProxy addLeakedObject:self];
    
    NSString *className = NSStringFromClass([self class]);
    NSLog(@"Possibly Memory Leak.\nIn case that %@ should not be dealloced, override -willDealloc in %@ by returning NO.\nView-ViewController stack: %@", className, className, [self JC_viewStack]);
}

- (void)JC_willReleaseObject:(id)object relationship:(NSString *)relationship {
    if ([relationship hasPrefix:@"self"]) {
        relationship = [relationship stringByReplacingCharactersInRange:NSMakeRange(0, 4) withString:@""];
    }
    NSString *className = NSStringFromClass([object class]);
    className = [NSString stringWithFormat:@"%@(%@), ", relationship, className];
    
    [object JC_setViewStack:[[self JC_viewStack] arrayByAddingObject:className]];
    [object JC_setParentPtrs:[[self JC_parentPtrs] setByAddingObject:@((uintptr_t)object)]];
    [object JC_willDealloc];
}

- (void)JC_willReleaseChild:(id)child {
    if (!child) {
        return;
    }
    
    [self JC_willReleaseChildren:@[ child ]];
}

- (void)JC_willReleaseChildren:(NSArray *)children {
    NSArray *viewStack = [self JC_viewStack];
    NSSet *parentPtrs = [self JC_parentPtrs];
    for (id child in children) {
        NSString *className = NSStringFromClass([child class]);
        [child JC_setViewStack:[viewStack arrayByAddingObject:className]];
        [child JC_setParentPtrs:[parentPtrs setByAddingObject:@((uintptr_t)child)]];
        [child JC_willDealloc];
    }
}

- (NSArray *)JC_viewStack {
    NSArray *viewStack = objc_getAssociatedObject(self, kViewStackKey);
    if (viewStack) {
        return viewStack;
    }
    
    NSString *className = NSStringFromClass([self class]);
    return @[ className ];
}

- (void)JC_setViewStack:(NSArray *)viewStack {
    objc_setAssociatedObject(self, kViewStackKey, viewStack, OBJC_ASSOCIATION_RETAIN);
}

- (NSSet *)JC_parentPtrs {
    NSSet *parentPtrs = objc_getAssociatedObject(self, kParentPtrsKey);
    if (!parentPtrs) {
        parentPtrs = [[NSSet alloc] initWithObjects:@((uintptr_t)self), nil];
    }
    return parentPtrs;
}

- (void)JC_setParentPtrs:(NSSet *)parentPtrs {
    objc_setAssociatedObject(self, kParentPtrsKey, parentPtrs, OBJC_ASSOCIATION_RETAIN);
}

+ (NSMutableSet *)JC_classNamesWhitelist {
    static NSMutableSet *whitelist = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        whitelist = [NSMutableSet setWithObjects:
                     @"UIFieldEditor", // UIAlertControllerTextField
                     @"UINavigationBar",
                     @"_UIAlertControllerActionView",
                     @"_UIVisualEffectBackdropView",
                     nil];
        
        // System's bug since iOS 10 and not fixed yet up to this ci.
        NSString *systemVersion = [UIDevice currentDevice].systemVersion;
        if ([systemVersion compare:@"10.0" options:NSNumericSearch] != NSOrderedAscending) {
            [whitelist addObject:@"UISwitch"];
        }
    });
    return whitelist;
}

+ (void)JC_addClassNamesToWhitelist:(NSArray *)classNames {
    [[self JC_classNamesWhitelist] addObjectsFromArray:classNames];
}

+ (void)JC_swizzleSEL:(SEL)originalSEL withSEL:(SEL)swizzledSEL {
#if _INTERNAL_MLF_ENABLED
    Class class = [self class];
    
    Method originalMethod = class_getInstanceMethod(class, originalSEL);
    Method swizzledMethod = class_getInstanceMethod(class, swizzledSEL);
    
    BOOL didAddMethod =
    class_addMethod(class,
                    originalSEL,
                    method_getImplementation(swizzledMethod),
                    method_getTypeEncoding(swizzledMethod));
    
    if (didAddMethod) {
        class_replaceMethod(class,
                            swizzledSEL,
                            method_getImplementation(originalMethod),
                            method_getTypeEncoding(originalMethod));
    } else {
        method_exchangeImplementations(originalMethod, swizzledMethod);
    }
#endif
}

@end
