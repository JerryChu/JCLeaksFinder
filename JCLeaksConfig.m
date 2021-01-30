//
//  JCLeaksConfig.m
//  FBRetainCycleDetector
//
//  Created by JerryChu on 2021/1/11.
//

#import "JCLeaksConfig.h"
#import "NSObject+MemoryLeak.h"
#import <FBRetainCycleDetector/FBRetainCycleDetector.h>

@implementation JCLeaksConfig

+ (JCLeaksConfig *)sharedInstance {
    static dispatch_once_t once;
    static JCLeaksConfig *config;
    dispatch_once(&once, ^{
        config = [[JCLeaksConfig alloc] init];
    });
    return config;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        self.detectThresholdInSeconds = 5;
        self.retainCycleMaxLength = 10;
        self.globalRetainMaxLength = 15;
        self.checkGlobalRetain = YES;

        [FBAssociationManager hook];
    }
    return self;
}

- (void)addClassNamesToWhiteList:(NSArray<NSString *> *)classNames {
    [NSObject JC_addClassNamesToWhitelist:classNames];
}

- (void)addObjectToWhiteList:(NSObject *)object {
    [object JC_markAsWhiteLeakedObject];
}

@end
