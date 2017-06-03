//
//  ViewController.m
//  NetworkRequest
//
//  Created by Ossey on 2017/6/3.
//  Copyright © 2017年 Ossey. All rights reserved.
//

#import "ViewController.h"
#import "NetworkRequest.h"
#import "SampleTableViewCell.h"
#import "SampleDownloadModel.h"


@interface ViewController ()


@end

@implementation ViewController {
    NSMutableArray<NSString *> *_imageUrls;
    
    NSMutableArray<SampleDownloadModel *> *_dataSource;
    
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    
    
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"加载" style:0 target:self action:@selector(downloadAllImage)];
    
    [self.tableView registerNib:[UINib nibWithNibName:@"SampleTableViewCell" bundle:nil] forCellReuseIdentifier:@"SampleTableViewCell"];
    _imageUrls = [NSMutableArray arrayWithArray:[self getImageUrls]];
    
    _dataSource = [NSMutableArray array];
}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


#pragma mark - load data

- (void)downloadAllImage {
    
    [_imageUrls enumerateObjectsUsingBlock:^(NSString * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        
        
        NSURL *url = [NSURL URLWithString:obj];
        
        NSURLRequest *request = [NSURLRequest requestWithURL:url cachePolicy:NSURLRequestReloadIgnoringCacheData timeoutInterval:15.0];
        OSOperation *op = [OSOperation operationWithRequest:request];
        [[NetworkRequest sharedInstance] addOperation:op startImmediately:NO];
        
        SampleDownloadModel *model = [SampleDownloadModel new];
        model.fileName = [obj lastPathComponent];
        op.completionHandler = ^(NSURLResponse *response, NSData *data, NSError *error) {
            
            if (!error) {
                UIImage *image = [UIImage imageWithData:data];
                if (image) {
                    model.image = image;
                }
            }
            
        };
        
        
        op.downloadProgressHandler = ^(float progress, NSInteger bytesTransferred, NSInteger totalBytes) {
            
            model.progress = progress;
            model.bytesTransferred = bytesTransferred;
            model.totalBytes = totalBytes;
        };
        
        op.requestStatusHandler = ^(OSRequestStatus requestState) {
            model.statue = requestState;
            
        };
        
        [_dataSource addObject:model];
    }];
    
    [self refreshView];
}

- (void)refreshView {
    
    [self.tableView reloadData];
    
    // 更新按钮的状态
    if ([[NetworkRequest sharedInstance] requestCount]) {
        // 正在加载中
        self.navigationItem.rightBarButtonItem.enabled = NO;
        self.navigationItem.rightBarButtonItem.title = @"等待中";
        
    } else if ([_imageUrls count]) {
        self.navigationItem.rightBarButtonItem.enabled = YES;
        self.navigationItem.rightBarButtonItem.title = @"清除";
    } else {
        self.navigationItem.rightBarButtonItem.enabled = YES;
        self.navigationItem.rightBarButtonItem.title = @"下载";
    }
}

#pragma mark - UITableViewController

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    
    return [_dataSource count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    SampleTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"SampleTableViewCell" forIndexPath:indexPath];
    
    
    cell.model = _dataSource[indexPath.row];
    cell.startCallBack = ^{
        NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:_imageUrls[indexPath.row]] cachePolicy:NSURLRequestReloadIgnoringCacheData timeoutInterval:15.0];
        [[NetworkRequest sharedInstance] startRequest:request];
    };
    return cell;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    return 225;
}

- (void)tableView:(__unused UITableView *)tableView didSelectRowAtIndexPath:(__unused NSIndexPath *)indexPath {
    UIViewController *viewController = [[UIViewController alloc] init];
    
    //    NSString *urlString = _imageUrls[indexPath.row];
    //    UIImage *image = _images[urlString];
    //    UIImageView *imageView = [[UIImageView alloc] initWithImage:image];
    //    viewController.view = imageView;
    
    [self.navigationController pushViewController:viewController animated:YES];
}

- (NSArray <NSString *> *)getImageUrls {
    return @[
             @"http://sw.bos.baidu.com/sw-search-sp/software/447feea06f61e/QQ_mac_5.5.1.dmg",
             @"http://dlsw.baidu.com/sw-search-sp/soft/b4/25734/itunes12.3.1442478948.dmg",
             @"http://sw.bos.baidu.com/sw-search-sp/software/9d93250a5f604/QQMusic_mac_4.2.3.dmg",
             @"https://ss0.bdstatic.com/70cFvHSh_Q1YnxGkpoWK1HF6hhy/it/u=3494814264,3775539112&fm=21&gp=0.jpg",
             @"https://ss3.bdstatic.com/70cFv8Sh_Q1YnxGkpoWK1HF6hhy/it/u=1996306967,4057581507&fm=21&gp=0.jpg",
             @"https://ss0.bdstatic.com/70cFvHSh_Q1YnxGkpoWK1HF6hhy/it/u=2844924515,1070331860&fm=21&gp=0.jpg",
             @"https://ss3.bdstatic.com/70cFv8Sh_Q1YnxGkpoWK1HF6hhy/it/u=3978900042,4167838967&fm=21&gp=0.jpg",
             @"https://ss1.bdstatic.com/70cFvXSh_Q1YnxGkpoWK1HF6hhy/it/u=516632607,3953515035&fm=21&gp=0.jpg",
             @"https://ss0.bdstatic.com/70cFuHSh_Q1YnxGkpoWK1HF6hhy/it/u=3180500624,3814864146&fm=21&gp=0.jpg",
             @"https://ss0.bdstatic.com/70cFvHSh_Q1YnxGkpoWK1HF6hhy/it/u=3335283146,3705352490&fm=21&gp=0.jpg",
             @"https://ss0.bdstatic.com/70cFvHSh_Q1YnxGkpoWK1HF6hhy/it/u=4090348863,2338325058&fm=21&gp=0.jpg",
             @"https://ss0.bdstatic.com/70cFvHSh_Q1YnxGkpoWK1HF6hhy/it/u=3800219769,1402207302&fm=21&gp=0.jpg",
             @"https://ss3.bdstatic.com/70cFv8Sh_Q1YnxGkpoWK1HF6hhy/it/u=1534694731,2880365143&fm=21&gp=0.jpg",
             @"https://ss1.bdstatic.com/70cFvXSh_Q1YnxGkpoWK1HF6hhy/it/u=1155733552,156192689&fm=21&gp=0.jpg",
             @"https://ss3.bdstatic.com/70cFv8Sh_Q1YnxGkpoWK1HF6hhy/it/u=3325163039,3163028420&fm=21&gp=0.jpg",
             @"https://ss3.bdstatic.com/70cFv8Sh_Q1YnxGkpoWK1HF6hhy/it/u=2090484547,151176521&fm=21&gp=0.jpg",
             @"https://ss2.bdstatic.com/70cFvnSh_Q1YnxGkpoWK1HF6hhy/it/u=2722857883,3187461130&fm=21&gp=0.jpg",
             @"https://ss1.bdstatic.com/70cFvXSh_Q1YnxGkpoWK1HF6hhy/it/u=3443126769,3454865923&fm=21&gp=0.jpg",
             @"https://ss3.bdstatic.com/70cFv8Sh_Q1YnxGkpoWK1HF6hhy/it/u=283169269,3942842194&fm=21&gp=0.jpg",
             @"https://ss0.bdstatic.com/70cFvHSh_Q1YnxGkpoWK1HF6hhy/it/u=2522613626,1679950899&fm=21&gp=0.jpg",
             @"https://ss0.bdstatic.com/70cFvHSh_Q1YnxGkpoWK1HF6hhy/it/u=2307958387,2904044619&fm=21&gp=0.jpg",
             ];
}

@end
