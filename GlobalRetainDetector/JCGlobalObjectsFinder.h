//
//  JCGlobalObjectsFinder.h
//  QJCews
//
//  Created by JerryChu on 2020/12/3.
//  Copyright © 2020 JerryChu. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface JCGlobalObjectsFinder : NSObject

/// 获取所有全局对象（__DATA.__bss section）
+ (NSArray<NSObject *> *)globalObjects;

@end

NS_ASSUME_NONNULL_END
