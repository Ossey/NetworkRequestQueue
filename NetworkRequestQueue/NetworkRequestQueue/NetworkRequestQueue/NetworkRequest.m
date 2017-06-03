//
//  NetworkRequest.m
//  NetworkRequest
//
//  Created by Ossey on 2017/6/3.
//  Copyright © 2017年 Ossey. All rights reserved.
//

#import "NetworkRequest.h"

#pragma GCC diagnostic ignored "-Wobjc-missing-property-synthesis"
#pragma GCC diagnostic ignored "-Wconversion"
#pragma GCC diagnostic ignored "-Wgnu"

NSString * const HTTPResponseErrorDomain = @"HTTPResponseErrorDomain";

@interface NetworkRequest ()

/// 所有的操作任务集合
@property (nonatomic, strong) NSMutableArray<OSOperation *> *operations;

@end

@implementation NetworkRequest

@dynamic sharedInstance;

+ (NetworkRequest *)sharedInstance {
    static NetworkRequest *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [NetworkRequest new];
    });
    return sharedInstance;
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        
        _requestMode = NetworkRequestModeFILO;
        _operations = [NSMutableArray arrayWithCapacity:2];
        _maxConcurrentRequestCount = 2;
        _allowDuplicateRequest = NO;
        
    }
    return self;
}

/// 执行操作
- (void)performOperations {
    // 防止并发资源抢夺问题，导致crash，加锁
    @synchronized (self) {
        if (!self.isSuspended) {
            
            NSInteger count = MIN([self.operations count], self.maxConcurrentRequestCount ?: INT_MAX);
            for (NSInteger i = 0; i < count; ++i) {
                if (!self.operations.count) {
                    return;
                }
                OSOperation *op = self.operations[i];
                [op start];
            }
        }
    }
    
}

#pragma mark - Public methods
- (void)setSuspended:(BOOL)suspended {
    _suspended = suspended;
    [self performOperations];
}

- (void)addOperation:(OSOperation *)op {
    
    // 不允许有重复的请求时
    if (!self.allowDuplicateRequest) {
        
        // 倒叙遍历operations
        [self.operations enumerateObjectsWithOptions:NSEnumerationReverse usingBlock:^(OSOperation * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            if ([obj.request isEqual:op.request]) {
                [obj cancel];
            }
        }];
    }
    
    // 允许有重复请求
    __block NSInteger index = 0;
    // FILO
    if (self.requestMode == NetworkRequestModeFILO) {
        index = [self.operations count];
        
    } else
        // LIFO
    {
        [self.operations enumerateObjectsUsingBlock:^(OSOperation * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            if (![obj isExecuting]) {
                *stop = YES;
            }
            index++;
        }];
    }
    
    if (index < [[self operations] count]) {
        [self.operations insertObject:op atIndex:index];
    } else {
        [self.operations addObject:op];
    }
    
    [op addObserver:self forKeyPath:@"isExecuting" options:NSKeyValueObservingOptionNew context:NULL];
    [self performOperations];
}

- (void)addRequest:(NSURLRequest *)request completionHandler:(OSCompletionHandler)completionHandler {
    OSOperation *op = [OSOperation operationWithRequest:request];
    op.completionHandler = completionHandler;
    [self addOperation:op];
}

- (void)cancelRequest:(NSURLRequest *)request {
    [self.operations enumerateObjectsWithOptions:NSEnumerationReverse usingBlock:^(OSOperation * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        if ([obj.request isEqual:request]) {
            [obj cancel];
        }
    }];
}

- (void)cancelAllRequests {
    
    NSArray *allOperations = [self operations];
    self.operations = [NSMutableArray array];
    [allOperations makeObjectsPerformSelector:@selector(cancel)];
}

#pragma mark - Private methods
- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSKeyValueChangeKey,id> *)change context:(void *)context {
    
    if ([keyPath isEqualToString:@"isExecuting"]) {
        OSOperation *op = object;
        if (![op isKindOfClass:[OSOperation class]]) {
            return;
        }
        [op removeObserver:self forKeyPath:keyPath];
        [self.operations removeObject:op];
        [self performOperations];
    }
}

#pragma mark - get

- (NSArray *)requests {
    return [self.operations valueForKeyPath:@"request"];
}

- (NSInteger)requestCount {
    return [self.operations count];
}



@end

@interface OSOperation () <NSURLConnectionDataDelegate>

@property (nonatomic, strong) NSURLConnection *connection;
/** 接收到服务器的的响应体对象 */
@property (nonatomic, strong) NSURLResponse *responseReceived;
/** 当前请求的到的数据 */
@property (nonatomic, strong) NSMutableData *accumulatedData;
@property (nonatomic, getter = isExecuting) BOOL executing;
@property (nonatomic, getter = isFinished) BOOL finished;
@property (nonatomic, getter = isCancelled) BOOL cancelled;

@property (nonatomic, strong) NSSet *runloopModes;

@end

@implementation OSOperation

@synthesize executing = _executing;
@synthesize finished = _finished;
@synthesize cancelled = _cancelled;

+ (instancetype)operationWithRequest:(NSURLRequest *)request {
    return [[self alloc] initWithRequest:request];
}

- (instancetype)initWithRequest:(NSURLRequest *)request {
    if (self = [self init]) {
        _request = request;
        _autoRetryDelay = 5.0;
        _autoRetry = NO;
        _runloopModes = [NSSet setWithObject:NSRunLoopCommonModes];
        _connection = [[NSURLConnection alloc] initWithRequest:request delegate:self startImmediately:NO];
    }
    return self;
}

- (BOOL)isConcurrent {
    return YES;
}

- (BOOL)isAsynchronous {
    return YES;
}

- (void)start {
    @synchronized (self) {
        [self performSelector:@selector(operationDidStart) onThread:[[self class] networkRequestThread] withObject:nil waitUntilDone:NO modes:[self.runloopModes allObjects]];
    }
}

- (void)operationDidStart {
    
    // 当不是正在执行，并且未取消时, 才开始下载
    if (!self.isExecuting && !self.isCancelled) {
        
        // 开始执行任务, 并标记为正在执行
        [self willChangeValueForKey:@"isExecuting"];
        self.executing = YES;
        [self.connection scheduleInRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
        NSRunLoop *runLoop = [NSRunLoop currentRunLoop];
        for (NSString *runLoopMode in self.runloopModes) {
            [self.connection scheduleInRunLoop:runLoop forMode:runLoopMode];
        }
        [self.connection start];
        [self didChangeValueForKey:@"isExecuting"];
        
    }
}

- (void)cancel {
    [self performSelector:@selector(cancelConnection) onThread:[[self class] networkRequestThread] withObject:nil waitUntilDone:NO modes:[self.runloopModes allObjects]];
}

- (void)cancelConnection {
    @synchronized (self) {
        // 当非取消状态时，取消请求任务，并标记为取消
        if (!self.isCancelled) {
            [self willChangeValueForKey:@"isCancelled"];
            self.cancelled = YES;
            [self.connection cancel];
            [self didChangeValueForKey:@"isCancelled"];
            
            // 让connection执行代理的失败方法回调
            NSError *error = [NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorCancelled userInfo:nil];
            [self connection:self.connection didFailWithError:error];
        }
    }
}

- (void)finish {
    @synchronized (self) {
        // 当正在执行，且未完成时, 标记为完成
        if (self.isExecuting && !self.isFinished) {
            [self willChangeValueForKey:@"isExecuting"];
            [self willChangeValueForKey:@"isFinished"];
            self.executing = NO;
            self.finished = YES;
            [self didChangeValueForKey:@"isFinished"];
            [self didChangeValueForKey:@"isExecuting"];
        }
    }
}

- (NSSet *)autoRetryErrorCodes {
    if (!_autoRetryErrorCodes) {
        static NSSet *codes = nil;
        if (!codes) {
            codes = [NSSet setWithObjects:
                     @(NSURLErrorTimedOut),
                     @(NSURLErrorCannotFindHost),
                     @(NSURLErrorCannotConnectToHost),
                     @(NSURLErrorDNSLookupFailed),
                     @(NSURLErrorNotConnectedToInternet),
                     @(NSURLErrorNetworkConnectionLost) ,nil];
        }
        _autoRetryErrorCodes = codes;
    }
    return _autoRetryErrorCodes;
}


#pragma mark - <NSURLConnectionDataDelegate>

/// 请求失败时调用
- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error {
    // 若autoRetry = YES(自动重新请求), 并且当前接收的错误信息是在autoRetryErrorCodes中的，就重新创建connection发起请求
    if (self.autoRetry && [self.autoRetryErrorCodes containsObject:@(error.code)]) {
        self.connection = [[NSURLConnection alloc] initWithRequest:self.request delegate:self startImmediately:NO];
        [_connection performSelector:@selector(start) withObject:nil afterDelay:self.autoRetryDelay];
    } else {
        
        // autoRetry = NO 时标记完成，执行completionHandler
        [self finish];
        self.connection = nil;
        dispatch_async(dispatch_get_main_queue(), ^{
            if (self.completionHandler) {
                self.completionHandler(self.responseReceived, self.accumulatedData, error);
            }
        });
        
    }
}

/// 需要HTTPS(SSL)认证时调用
- (void)connection:(NSURLConnection *)connection didReceiveAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge {
    if (self.authenticationChallengeHandler) {
        self.authenticationChallengeHandler(challenge);
    } else {
        [challenge.sender continueWithoutCredentialForAuthenticationChallenge:challenge];
    }
}

/// 服务器开始返回数据时调用
- (void)connection:(__unused NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response {
    self.responseReceived = response;
}

/// 发送数据给服务器时回调 post方法请求使用
- (void)connection:(NSURLConnection *)connection didSendBodyData:(NSInteger)bytesWritten totalBytesWritten:(NSInteger)totalBytesWritten totalBytesExpectedToWrite:(NSInteger)totalBytesExpectedToWrite {
    if (self.uploadProgressHandler) {
        dispatch_async(dispatch_get_main_queue(), ^{
            // 执行上传进度的block
            float progress = (float)totalBytesWritten / (float)totalBytesExpectedToWrite;
            self.uploadProgressHandler(progress, (float)totalBytesWritten, (float)totalBytesExpectedToWrite);
        });
        
    }
}

/// 接收服务器返回的数据 会被多次调用
- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data {
    
    // 将每次请求到的数据添加到accumulatedData中
    if (!self.accumulatedData) {
        self.accumulatedData = [[NSMutableData alloc] initWithCapacity:MAX(0, self.responseReceived.expectedContentLength)];
    }
    [self.accumulatedData appendData:data];
    if (self.downloadProgressHandler) {
        dispatch_async(dispatch_get_main_queue(), ^{
            // 当前请求数据的大小
            NSInteger bytesTransFerred = [self.accumulatedData length];
            // 预计文件的总大小
            NSInteger totalBytes = MAX(0, self.responseReceived.expectedContentLength);
            float progress = (float)bytesTransFerred / (float)totalBytes;
            NSLog(@"%f， connection：%p", progress, connection);
            self.downloadProgressHandler(progress, bytesTransFerred, totalBytes);
        });
        
    }
}

/// 请求完成调用
- (void)connectionDidFinishLoading:(NSURLConnection *)connection {
    
    NSError *error = nil;
    
    if ([self.responseReceived respondsToSelector:@selector(statusCode)]) {
        // HTTP请求的响应的状态码, 当>=400时就是错误
        NSInteger statusCode = [(NSHTTPURLResponse *)self.responseReceived statusCode];
        if (statusCode / 100 >= 4) {
            NSString *message = [NSString stringWithFormat:@"服务器返回错误%ld", statusCode];
            error = [NSError errorWithDomain:HTTPResponseErrorDomain
                                        code:statusCode
                                    userInfo:@{
                                               NSLocalizedDescriptionKey : message
                                               }];
        }
    }
    
    if (self.completionHandler) {
        dispatch_async(dispatch_get_main_queue(), ^{
            self.completionHandler(self.responseReceived, self.accumulatedData, error);
        });
    }
    
    [self finish];
    self.connection = nil;
}

#pragma mark - 常驻线程

+ (void)networkRequestThreadEntryPoint:(id)__unused object {
    @autoreleasepool {
        [[NSThread currentThread] setName:@"NetworkRequestQueue"];
        
        NSRunLoop *runLoop = [NSRunLoop currentRunLoop];
        [runLoop addPort:[NSMachPort port] forMode:NSDefaultRunLoopMode];
        [runLoop run];
    }
}

+ (NSThread *)networkRequestThread {
    static NSThread *_networkRequestThread = nil;
    static dispatch_once_t oncePredicate;
    dispatch_once(&oncePredicate, ^{
        _networkRequestThread = [[NSThread alloc] initWithTarget:self selector:@selector(networkRequestThreadEntryPoint:) object:nil];
        [_networkRequestThread start];
    });
    
    return _networkRequestThread;
}


@end
