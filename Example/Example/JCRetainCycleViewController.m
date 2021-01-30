//
//  JCRetainCycleViewController.m
//  Example
//
//  Created by JerryChu on 2021/1/11.
//

#import "JCRetainCycleViewController.h"
#import <JCLeaksFinder/JCLeaksConfig.h>

#pragma mark - JCLeaksCustomView

@interface JCLeaksCustomView : UIView

@property(nonatomic, copy) dispatch_block_t block;

@end

@implementation JCLeaksCustomView

@end

#pragma mark - JCRetainCycleViewController

@interface JCRetainCycleViewController ()

@property(nonatomic, strong) JCLeaksCustomView *customView;

@end

@implementation JCRetainCycleViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor whiteColor];
    [self.view addSubview:({
        UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
        [button setTitle:[NSString stringWithFormat:@"退出页面，等待 %@ 秒后展示检测结果", @([JCLeaksConfig sharedInstance].detectThresholdInSeconds)]  forState:UIControlStateNormal];
        [button setTitleColor:[UIColor blueColor] forState:UIControlStateNormal];
        [button addTarget:self action:@selector(p_dismiss) forControlEvents:UIControlEventTouchUpInside];
        [button setFrame:self.view.bounds];
        button;
    })];

    self.customView = [[JCLeaksCustomView alloc] initWithFrame:self.view.bounds];
    UIViewController *vc = self;
    _customView.block = ^{
        [vc isViewLoaded];
    };
}

- (void)p_dismiss {
    [self dismissViewControllerAnimated:YES completion:nil];
}

@end
