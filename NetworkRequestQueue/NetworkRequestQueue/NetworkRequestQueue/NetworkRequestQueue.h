//
//  NetworkRequestQueue.h
//  NetworkRequestQueue
//
//  Created by Ossey on 2017/6/3.
//  Copyright © 2017年 Ossey. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef void(^OSCompletionHandler)(NSURLResponse *response, NSData *data, NSError *error);
/// @param progress 请求进度
/// @param bytesTransferred 当前获取的数据大小
/// @param totalBytes 请求的数据的预计总大小
typedef void(^OSProgressHandler)(float progress, NSInteger bytesTransferred, NSInteger totalBytes);
typedef void(^OSAuthenticationChallengeHandler)(NSURLAuthenticationChallenge *challenge);

typedef NS_ENUM(NSInteger, NetworkRequestMode) {
    NetworkRequestModeFILO = 0, // 队列形式先进先出
    NetworkRequestModeLIFO,    // 栈形式后进先出
};

@interface OSOperation : NSOperation

/// 当请求完成、请求失败、取消请求时回调
@property (nonatomic, copy) OSCompletionHandler completionHandler;
/// 下载数据的进度回调
@property (nonatomic, copy) OSProgressHandler downloadProgressHandler;
/// 上传数据的进度回调
@property (nonatomic, copy) OSProgressHandler uploadProgressHandler;
/// 当服务器需要返回认证时回调
@property (nonatomic, copy) OSAuthenticationChallengeHandler authenticationChallengeHandler;

/// 请求对象
@property (nonatomic, strong, readonly) NSURLRequest *request;
/// 自动重试时间
@property (nonatomic, assign) NSTimeInterval autoRetryDelay;
/// 是否自动重试, 当请求失败时，若设置此属性为YES,且当前失败的code为autoRetryErrorCodes中的，就会在autoRetryDelay设定的时间后重新发起请求
@property (nonatomic, assign) BOOL autoRetry;
/// 只有符合这些错误code才允许自动重试 
@property (nonatomic, strong) NSSet *autoRetryErrorCodes;

+ (instancetype)operationWithRequest:(NSURLRequest *)request;

@end

@interface NetworkRequestQueue : NSObject

@property (nonatomic, copy, readonly, class) NetworkRequestQueue *mainQueue;
/// 此属性控制新的请求是添加在请求操作集合的最前面还是最后面，默认为NetworkRequestModeFILO(那新的请求会放在操作集合的最后面完成)，当为NetworkRequestModeLIFO时新的请求会优先执行，正在请求的任务不受影响
@property (nonatomic, assign) NetworkRequestMode requestMode;
/// 并发请求的最大数量，当添加更多请求时，会添加到请求操作的队列中等待完成再执行，当值为0时请求的数量没有限制，值为1时一次只能请求一个，默认值为2
@property (nonatomic, assign) NSInteger maxConcurrentRequestCount;
/// 是否继续或暂停请求，已经在进度的请求不会触发此属性
@property (nonatomic, assign, getter=isSuspended) BOOL suspended;
/// 请求操作队列中的数量，包括请求中和未请求的
@property (nonatomic, assign, readonly) NSInteger requestCount;
/// 包括请求中和未请求的, 操作集合的每一个元素的NSURLRequest *request对象
@property (nonatomic, strong, readonly) NSArray<NSURLRequest *> *requests;
/// 是否允许当前操作集合中有重复的请求，默认为NO，当添加的操作(请求的参数相同)已经在操作队列中包含时，则会将添加的操作删除
@property (nonatomic, assign) BOOL allowDuplicateRequest;


- (void)addOperation:(OSOperation *)op;
- (void)addRequest:(NSURLRequest *)request completionHandler:(OSCompletionHandler)completionHandler;
- (void)cancelRequest:(NSURLRequest *)request;
- (void)cancelAllRequests;

@end
