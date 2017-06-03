//
//  SampleTableViewCell.h
//  NetworkRequestQueue
//
//  Created by Ossey on 2017/6/3.
//  Copyright © 2017年 Ossey. All rights reserved.
//

#import <UIKit/UIKit.h>

@class SampleDownloadModel;

@interface SampleTableViewCell : UITableViewCell

@property (nonatomic, copy) void (^startCallBack)();

@property (nonatomic, strong) SampleDownloadModel *model;

@end
