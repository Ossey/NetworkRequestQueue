//
//  SampleTableViewCell.m
//  NetworkRequestQueue
//
//  Created by Ossey on 2017/6/3.
//  Copyright © 2017年 Ossey. All rights reserved.
//

#import "SampleTableViewCell.h"
#import "SampleDownloadModel.h"
#import "NetworkRequest.h"

@interface SampleTableViewCell ()

@property (weak, nonatomic) IBOutlet UILabel *nameLabel;
@property (weak, nonatomic) IBOutlet UILabel *fileSizeLabel;
@property (weak, nonatomic) IBOutlet UIImageView *iconView;
@property (weak, nonatomic) IBOutlet UIProgressView *progressView;
@property (weak, nonatomic) IBOutlet UIButton *downloadStatuBtn;

@end

@implementation SampleTableViewCell {
    
    NSInteger _statues;
}

- (void)awakeFromNib {
    [super awakeFromNib];
    // Initialization code
    _statues = 0;
    _nameLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    [_nameLabel setFont:[UIFont systemFontOfSize:15 weight:1.0]];
    [_fileSizeLabel setFont:[UIFont systemFontOfSize:13 weight:1.0]];
}


- (void)setSelected:(BOOL)selected animated:(BOOL)animated {
    [super setSelected:selected animated:animated];
    
    // Configure the view for the selected state
}
- (IBAction)downloadStatuBtnClick:(id)sender {
    
    if (self.startCallBack) {
        self.startCallBack();
    }
    
}

- (void)setModel:(SampleDownloadModel *)model {
    _model = model;
    
    __weak typeof(self) weakSelf = self;
    [self loadData];
    model.refreshDataCallBack = ^{
        [weakSelf loadData];
    };
    
}

- (void)loadData {
    
    self.iconView.image = self.model.image;
    self.progressView.progress = self.model.progress;
    
    NSString *bytesTransferred = [[self class] transformedFileSizeValue:@(self.model.bytesTransferred)];
    NSString *totalSize = [[self class] transformedFileSizeValue:@(self.model.totalBytes)];
    self.fileSizeLabel.text = [NSString stringWithFormat:@"%@/%@", bytesTransferred, totalSize];
    self.nameLabel.text = self.model.fileName;
    
    
    if (_statues != self.model.statue) {
        _statues = self.model.statue;
        switch (self.model.statue) {
            case OSRequestPaused:
            {
                [self.downloadStatuBtn setTitle:@"已暂停" forState:UIControlStateNormal];
                [self.downloadStatuBtn sizeToFit];
            }
                break;
            case OSRequestFinish:
            {
                [self.downloadStatuBtn setTitle:@"已完成" forState:UIControlStateNormal];
                [self.downloadStatuBtn sizeToFit];
            }
                break;
            case OSRequestCanceled:
            {
                [self.downloadStatuBtn setTitle:@"已取消" forState:UIControlStateNormal];
                [self.downloadStatuBtn sizeToFit];
            }
                break;
            case OSRequestFailure:
            {
                [self.downloadStatuBtn setTitle:@"下载失败" forState:UIControlStateNormal];
                [self.downloadStatuBtn sizeToFit];
            }
                break;
            case OSRequestExecuting: {
                [self.downloadStatuBtn setTitle:@"下载中" forState:UIControlStateNormal];
                [self.downloadStatuBtn sizeToFit];
            }
                break;
            default:
            {
                [self.downloadStatuBtn setTitle:@"开始" forState:UIControlStateNormal];
                [self.downloadStatuBtn sizeToFit];
                
            }
                break;
        }
        
    }
    
    
    
}

+ (NSString *)transformedFileSizeValue:(NSNumber *)value {
    
    double convertedValue = [value doubleValue];
    int multiplyFactor = 0;
    
    NSArray *tokens = [NSArray arrayWithObjects:@"bytes",@"KB",@"MB",@"GB",@"TB",@"PB", @"EB", @"ZB", @"YB",nil];
    
    while (convertedValue > 1024) {
        convertedValue /= 1024;
        multiplyFactor++;
    }
    
    return [NSString stringWithFormat:@"%4.2f %@",convertedValue, [tokens objectAtIndex:multiplyFactor]];
}

- (void)dealloc {
    
    NSLog(@"%s", __func__);
}

@end
