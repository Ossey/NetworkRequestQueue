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

#define OSPerformSelectorLeakWarning(Stuff) \
do { \
_Pragma("clang diagnostic push") \
_Pragma("clang diagnostic ignored \"-Warc-performSelector-leaks\"") \
Stuff; \
_Pragma("clang diagnostic pop") \
} while (0)


NSString * const HTTPResponseErrorDomain = @"HTTPResponseErrorDomain";


@interface NetworkRequest ()

/// 所有的操作任务集合
@property (nonatomic, strong) NSMutableArray<OSOperation *> *operations;
/// 立即执行任务
@property (nonatomic, assign) BOOL startImmediately;

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
- (void)startAllRequests {
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
    [self startAllRequests];
}

- (void)addOperation:(OSOperation *)op {
    
    [self addOperation:op startImmediately:YES];
}

- (void)addOperation:(OSOperation *)op startImmediately:(BOOL)startImmediately {
    _startImmediately = startImmediately;
    // 不允许有重复的请求时
    if (!self.allowDuplicateRequest) {
        
        // 倒叙遍历operations
        [self.operations enumerateObjectsWithOptions:NSEnumerationReverse usingBlock:^(OSOperation * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            if ([obj.request.URL.absoluteString isEqual:op.request.URL.absoluteString]) {
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
    
    [op addObserver:self forKeyPath:@"isFinished" options:NSKeyValueObservingOptionNew context:NULL];
    [op addObserver:self forKeyPath:@"requestState" options:NSKeyValueObservingOptionNew context:NULL];
    if (self.startImmediately) {
        [self startAllRequests];
    }
}

- (void)addRequest:(NSURLRequest *)request completionHandler:(OSCompletionHandler)completionHandler {
    OSOperation *op = [OSOperation operationWithRequest:request];
    op.completionHandler = completionHandler;
    [self addOperation:op];
}

- (void)startRequest:(NSURLRequest *)request {
    [self.operations enumerateObjectsWithOptions:NSEnumerationReverse usingBlock:^(OSOperation * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        if ([obj.request.URL.absoluteString isEqualToString:request.URL.absoluteString]) {
            SEL selector = NSSelectorFromString(@"setRequest:");
            OSPerformSelectorLeakWarning(
                                         [obj performSelector:selector withObject:request];
                                         );
            [obj start];
            *stop = YES;
        }
    }];
}

- (void)cancelRequest:(NSURLRequest *)request {
    [self.operations enumerateObjectsWithOptions:NSEnumerationReverse usingBlock:^(OSOperation * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        if ([obj.request.URL.absoluteString isEqualToString:request.URL.absoluteString]) {
            [obj cancel];
            *stop = YES;
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
    
    OSOperation *op = object;
    if (![op isKindOfClass:[OSOperation class]]) {
        return;
    }
    if ([keyPath isEqualToString:@"isFinished"]) {
        [op removeObserver:self forKeyPath:keyPath];
        [op removeObserver:self forKeyPath:@"requestState"];
        [self.operations removeObject:op];
        if (self.startImmediately) {
            [self startAllRequests];
        }
    }
    
    if ([keyPath isEqualToString:@"requestState"]) {
        if (op.requestState == OSRequestFailure) {
            [op removeObserver:self forKeyPath:keyPath];
            // 尝试重新下载
            //            [op start];
        }
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
@property (nonatomic, getter = isPaused) BOOL pause;

@property (nonatomic, strong) NSSet *runloopModes;
@property (nonatomic, strong) NSURLRequest *request;

@end

@implementation OSOperation

@synthesize executing = _executing;
@synthesize finished = _finished;
@synthesize cancelled = _cancelled;
@synthesize request = _request;

+ (instancetype)operationWithRequest:(NSURLRequest *)request {
    return [[self alloc] initWithRequest:request];
}

- (instancetype)initWithRequest:(NSURLRequest *)request {
    if (self = [self init]) {
        _request = request;
        _autoRetryDelay = 5.0;
        _autoRetry = NO;
        _runloopModes = [NSSet setWithObject:NSRunLoopCommonModes];
        _requestState = 0;
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
        self.requestState = OSRequestExecuting;
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
        if (self.isCancelled || self.isFinished) {
            [self finish];
        } else {
            [self willChangeValueForKey:@"isCancelled"];
            self.cancelled = YES;
            [self.connection cancel];
            self.requestState = OSRequestCanceled;
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
            self.requestState = OSRequestFinish;
            [self didChangeValueForKey:@"isFinished"];
            [self didChangeValueForKey:@"isExecuting"];
        }
    }
}

- (void)failure {
    @synchronized (self) {
        if (self.requestState != OSRequestFailure) {
            [self willChangeValueForKey:@"isExecuting"];
            self.executing = NO;
            self.requestState = OSRequestFailure;
            [self didChangeValueForKey:@"isExecuting"];
        }
    }
}

- (void)pause {
    if ([self isPaused] || [self isFinished] || [self isCancelled]) {
        return;
    }
    
    @synchronized (self) {
        if ([self isExecuting]) {
            [self performSelector:@selector(operationDidPause) onThread:[[self class] networkRequestThread] withObject:nil waitUntilDone:NO modes:[self.runloopModes allObjects]];
        }
        
        self.requestState = OSRequestPaused;
    }
    
}

- (BOOL)isPaused {
    return self.requestState == OSRequestPaused;
}

- (void)resume {
    if (![self isPaused]) {
        return;
    }
    
    @synchronized (self) {
        [self start];
    }
    
}

- (void)operationDidPause {
    @synchronized (self) {
        [self.connection cancel];
    }
}

- (NSURLConnection *)connection {
    if (!_connection) {
        _connection = [[NSURLConnection alloc] initWithRequest:self.request delegate:self startImmediately:NO];
    }
    return _connection;
}

- (void)setRequestState:(OSRequestStatus)requestState {
    
    if (_requestState != requestState && requestState != 0) {
        _requestState = requestState;
        dispatch_async(dispatch_get_main_queue(), ^{
            if (self.requestStatusHandler) {
                self.requestStatusHandler(requestState);
            }
        });
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
        self.requestState = OSRequestFailure;
        [self.connection performSelector:@selector(start) withObject:nil afterDelay:self.autoRetryDelay];
    } else {
        
        if (error.code != NSURLErrorCancelled) {
            [self failure];
            _connection = nil;
            
            dispatch_async(dispatch_get_main_queue(), ^{
                if (self.completionHandler) {
                    self.completionHandler(self.responseReceived, self.accumulatedData, error);
                }
            });
        }
        
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



