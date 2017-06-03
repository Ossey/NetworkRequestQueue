//
//  SampleDownloadModel.h
//  NetworkRequestQueue
//
//  Created by Ossey on 2017/6/4.
//  Copyright © 2017年 Ossey. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface SampleDownloadModel : NSObject

@property (nonatomic, strong) NSData *data;
@property (nonatomic, assign) CGFloat progress;
@property (nonatomic, assign) NSInteger statue;
@property (nonatomic, copy) NSString *fileName;
@property (nonatomic, assign) NSInteger bytesTransferred;
@property (nonatomic, assign) NSInteger totalBytes;


@property (nonatomic, copy) void (^ refreshDataCallBack)();

@end
