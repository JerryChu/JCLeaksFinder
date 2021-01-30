//
//  JCGlobalRetainViewController.m
//  Example
//
//  Created by JerryChu on 2021/1/11.
//

#import "JCGlobalRetainViewController.h"
#import <JCLeaksFinder/JCLeaksConfig.h>

static NSMutableArray<UIViewController *> *sGlobalVCArray = nil;

@interface JCGlobalRetainViewController ()

@end

@implementation JCGlobalRetainViewController

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

    sGlobalVCArray = [NSMutableArray array];
    [sGlobalVCArray addObject:self];
}

- (void)p_dismiss {
    [self dismissViewControllerAnimated:YES completion:nil];
}

@end
