//
//  ViewController.m
//  NetworkRequestQueue
//
//  Created by Ossey on 2017/6/3.
//  Copyright © 2017年 Ossey. All rights reserved.
//

#import "ViewController.h"
#import "NetworkRequestQueue.h"
#import "SampleTableViewCell.h"

@interface ViewController ()


@end

@implementation ViewController {
    NSMutableArray<NSString *> *_imageUrls;
    NSMutableDictionary *_images;
    NSMutableDictionary *_progressStatues;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.


    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"加载" style:0 target:self action:@selector(loadDataFromNetwork)];
    
    [self.tableView registerNib:[UINib nibWithNibName:@"SampleTableViewCell" bundle:nil] forCellReuseIdentifier:@"SampleTableViewCell"];
}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


#pragma mark - load data

- (void)loadDataFromNetwork {
    
    if ([_imageUrls count]) {
        _imageUrls = nil;
        _images = nil;
        _progressStatues = nil;
        
        [self refreshView];
    } else {
        _imageUrls = [NSMutableArray arrayWithArray:[self getImageUrls]];
        _images = [NSMutableDictionary dictionary];
        _progressStatues = [NSMutableDictionary dictionary];
        
        [self refreshView];
        
        [_imageUrls enumerateObjectsUsingBlock:^(NSString * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            
            NSURL *url = [NSURL URLWithString:obj];
            
            NSURLRequest *request = [NSURLRequest requestWithURL:url cachePolicy:NSURLRequestReloadIgnoringCacheData timeoutInterval:15.0];
            
            OSOperation *op = [OSOperation operationWithRequest:request];
            
            op.completionHandler = ^(NSURLResponse *response, NSData *data, NSError *error) {
              
                if (!error) {
                    UIImage *image = [UIImage imageWithData:data];
                    if (image) {
                        // 成功获取到图片
                        [_images setObject:image forKey:obj];
                        
                    } else {
                        // 未获取到图片
                        [_imageUrls replaceObjectAtIndex:idx withObject:[error localizedDescription]];
                    }
                }
                
                [self refreshView];
            };
            
            
            op.downloadProgressHandler = ^(float progress, NSInteger bytesTransferred, NSInteger totalBytes) {
              
                [_progressStatues setValue:@(progress) forKey:obj];
                
                [self refreshView];
            };
            
            [[NetworkRequestQueue mainQueue] addOperation:op];
        }];
    }
    
}

- (void)refreshView {
    
    [self.tableView reloadData];
    
    // 更新按钮的状态
    if ([[NetworkRequestQueue mainQueue] requestCount]) {
        // 正在加载中
        self.navigationItem.rightBarButtonItem.enabled = NO;
        self.navigationItem.rightBarButtonItem.title = @"等待中";
        
    }else if ([_imageUrls count]) {
        self.navigationItem.rightBarButtonItem.enabled = YES;
        self.navigationItem.rightBarButtonItem.title = @"Clear";
    } else {
        self.navigationItem.rightBarButtonItem.enabled = YES;
        self.navigationItem.rightBarButtonItem.title = @"Load";
    }
}

#pragma mark - UITableViewController

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    
    return [_imageUrls count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    SampleTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"SampleTableViewCell" forIndexPath:indexPath];
    
    NSString *urlStr = _imageUrls[indexPath.row];
    cell.iconView.image = _images[urlStr];
    
    cell.progressView.progress = [_progressStatues[urlStr] floatValue];
    
    return cell;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    return 225;
}

- (void)tableView:(__unused UITableView *)tableView didSelectRowAtIndexPath:(__unused NSIndexPath *)indexPath {
    UIViewController *viewController = [[UIViewController alloc] init];
    
    NSString *urlString = _imageUrls[indexPath.row];
    UIImage *image = _images[urlString];
    UIImageView *imageView = [[UIImageView alloc] initWithImage:image];
    viewController.view = imageView;
    
    [self.navigationController pushViewController:viewController animated:YES];
}

- (NSArray <NSString *> *)getImageUrls {
    return @[
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
