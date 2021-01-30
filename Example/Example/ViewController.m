//
//  ViewController.m
//  Example
//
//  Created by JerryChu on 2021/1/11.
//

#import "ViewController.h"
#import "JCRetainCycleViewController.h"
#import "JCGlobalRetainViewController.h"
#import <JCLeaksFinder/JCLeaksConfig.h>

@interface ViewController () <UITableViewDelegate, UITableViewDataSource>

@property(nonatomic, strong) UITableView *tableView;
@property(nonatomic, copy) NSArray<NSString *> *operationArray;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"JCLeaksFinder";
    
    [self.view addSubview:({
        UITableView *tableView = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStyleGrouped];
        tableView.dataSource = self;
        tableView.delegate = self;
        [tableView registerClass:[UITableViewCell class] forCellReuseIdentifier:@"identifier"];
        _tableView = tableView;
        tableView;
    })];

    _operationArray = @[@"循环引用", @"全局对象引用"];

    __weak typeof(self) weakSelf = self;
    [JCLeaksConfig sharedInstance].callback = ^(NSObject * _Nonnull leakedObject, NSSet * _Nonnull retainInfo, NSArray<NSString *> * _Nonnull viewStack) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        dispatch_async(dispatch_get_main_queue(), ^{
            UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"内存泄漏"
                                                                           message:[NSString stringWithFormat:@"%@\n%@", leakedObject, retainInfo]
                                                                    preferredStyle:UIAlertControllerStyleAlert];
            [alert addAction:[UIAlertAction actionWithTitle:@"确认" style:UIAlertActionStyleCancel handler:nil]];

            UIViewController *vc = strongSelf;
            while (vc.presentedViewController) {
                vc = vc.presentedViewController;
            }
            [vc presentViewController:alert animated:YES completion:nil];
        });
    };
}

#pragma mark - UITableViewDataSource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.operationArray.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"identifier" forIndexPath:indexPath];
    cell.textLabel.text = self.operationArray[indexPath.row];
    return cell;
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:NO];

    switch (indexPath.row) {
        case 0:
            [self p_simulateRetainCycle];
            break;
        case 1:
            [self p_simulateGlobalRetain];
            break;
        default:
            break;
    }
}

- (void)p_simulateRetainCycle {
    JCRetainCycleViewController *vc = [[JCRetainCycleViewController alloc] init];
    [self presentViewController:vc animated:YES completion:nil];
}

- (void)p_simulateGlobalRetain {
    JCGlobalRetainViewController *vc = [[JCGlobalRetainViewController alloc] init];
    [self presentViewController:vc animated:YES completion:nil];
}

@end
