//
//  SampleDownloadModel.m
//  NetworkRequestQueue
//
//  Created by Ossey on 2017/6/4.
//  Copyright © 2017年 Ossey. All rights reserved.
//

#import "SampleDownloadModel.h"

@implementation SampleDownloadModel

- (instancetype)init
{
    self = [super init];
    if (self) {
        _image = nil;
        _progress = 0.0;
        _statue = 0;
    }
    return self;
}

- (void)setImage:(UIImage *)image {
    
    _image = image;
    
    [self perforRefresh];
}

- (void)setStatue:(NSInteger)statue {
    
    _statue = statue;
    
    [self perforRefresh];
}

- (void)setProgress:(CGFloat)progress {
    
    _progress = progress;
    
    [self perforRefresh];
}

- (void)perforRefresh {
    if (self.refreshDataCallBack) {
        self.refreshDataCallBack();
    }
}

@end
