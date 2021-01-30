# JCLeaksFinder

iOS 内存泄漏检测组件，基于 `MLeaksFinder` 和 `FBRetainCycleDetector`，支持检测内存泄漏并自动输出 **循环引用链** 和 **全局对象引用链**。

## 特性

- 支持检测ViewController/View内存泄漏
- 支持添加自定义白名单
- 支持自动输出循环引用链
- 支持自动输出全局对象引用链（自研）
- 优化接口，使用更方便

## 安装 

```
pod 'JCLeaksFinder'
```

> `JCLeaksFinder` 内部依赖 `MLeaksFinder` 和 `FBRetainCycleDetector`。 `MLeaksFinder` 以源码方式引入，`FBRetainCycleDetector` 以 *dependency* 方式引入。


## 使用

无需额外操作，添加 *callback* 之后就能自动获取内存泄漏信息。

```objc
[JCLeaksConfig sharedInstance].callback = ^(NSObject * _Nonnull leakedObject, NSSet * _Nonnull retainInfo, NSArray<NSString *> * _Nonnull viewStack) {
    // do something
};
```

同时也支持丰富的自定义配置。

```objc
interface JCLeaksConfig : NSObject

+ (JCLeaksConfig *)sharedInstance;

/// 内存泄漏检测结果回调
/// leakedObject -> 泄漏对象
/// retainInfo -> 引用链信息，可能包含多个。不用关心`retainInfo`的具体数据，直接调用`[retainInfo description]`输出结果即可。
/// viewStack -> 泄漏对象层级信息
@property(nonatomic, copy) JCLeaksFinderCallback callback;

/// 检测阈值，默认为5s。退出页面`detectThresholdInSeconds`秒后开始检测是否有内存泄漏。
@property(nonatomic, assign) NSUInteger detectThresholdInSeconds;

/// 检测循环引用的最大引用链长度，默认为`10`。
@property(nonatomic, assign) NSUInteger retainCycleMaxLength;

/// 检测全局对象引用的最大引用链长度，默认为`15`。
@property(nonatomic, assign) NSUInteger globalRetainMaxLength;

/// 是否检测全局对象引用，默认为`YES`。检测全局对象引用耗时较高（约2-3s），在子线程进行
@property(nonatomic, assign) BOOL checkGlobalRetain;

/// 添加自定义的全局对象，默认为`nil`。
/// 有些对象并不是全局对象，但是会在APP生命周期内一直存活，如APP的rootNavigationController、rootTabBarController等
/// 在检测进行全局对象时，会将 `extraGlobalObjects` 也作为全局对象进行引用检测
@property(nonatomic, copy) NSArray<NSObject *> *extraGlobalObjects;

/// 添加白名单类名
- (void)addClassNamesToWhiteList:(NSArray<NSString *> *)classNames;

/// 添加白名单对象。该对象不会被内部持有。
- (void)addObjectToWhiteList:(NSObject *)object;

@end
```

## MLeaksFinder 文档

参考：https://github.com/Tencent/MLeaksFinder/blob/master/README.md

## FBRetainCycleDetector 文档

参考：https://github.com/facebook/FBRetainCycleDetector/blob/master/README.md

## 全局对象引用检测原理

参考：https://blog.jerrychu.top/2020/12/05/%E5%86%85%E5%AD%98%E6%B3%84%E6%BC%8F%E6%A3%80%E6%B5%8B%E6%9C%80%E4%BD%B3%E5%AE%9E%E8%B7%B5/
