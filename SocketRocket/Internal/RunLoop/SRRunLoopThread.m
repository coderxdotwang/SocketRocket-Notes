//
// Copyright 2012 Square Inc.
// Portions Copyright (c) 2016-present, Facebook, Inc.
//
// All rights reserved.
//
// This source code is licensed under the BSD-style license found in the
// LICENSE file in the root directory of this source tree. An additional grant
// of patent rights can be found in the PATENTS file in the same directory.
//

#import "SRRunLoopThread.h"

@interface SRRunLoopThread ()
{
    dispatch_group_t _waitGroup;
}

@property (nonatomic, strong, readwrite) NSRunLoop *runLoop;

@end

@implementation SRRunLoopThread

/// 单例
///
/// 初始化完成后就 start 启动线程。
+ (instancetype)sharedThread
{
    static SRRunLoopThread *thread;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        thread = [[SRRunLoopThread alloc] init];
        thread.name = @"com.facebook.SocketRocket.NetworkThread";
        [thread start];
    });
    return thread;
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        _waitGroup = dispatch_group_create();
        dispatch_group_enter(_waitGroup);
    }
    return self;
}

/**
 override 复写 NSThread `main` 方法：不需要调用对应的 `super` 方法。
 且不能直接调用 `main` 方法，而是通过 `start` 方法启动线程。
*/
- (void)main
{
    @autoreleasepool {
        _runLoop = [NSRunLoop currentRunLoop]; // 如果当前线程还没有对应的 runloop，则会创建一个。
        dispatch_group_leave(_waitGroup);

        // Add an empty run loop source to prevent runloop from spinning.
        // 添加一个空的 RunLoop 源，以阻止 RunLoop 退出。
        //（spinning：旋转？这里指在没有 输入源 Input Sources / 定时器 timers 需要处理时，
        // 开启 RunLoop 后，默认循环运行一次就会退出，对应的线程进入休眠状态。
        CFRunLoopSourceContext sourceCtx = {
            .version = 0,
            .info = NULL,
            .retain = NULL,
            .release = NULL,
            .copyDescription = NULL,
            .equal = NULL,
            .hash = NULL,
            .schedule = NULL,
            .cancel = NULL,
            .perform = NULL
        };
        CFRunLoopSourceRef source = CFRunLoopSourceCreate(NULL, 0, &sourceCtx);
        CFRunLoopAddSource(CFRunLoopGetCurrent(), source, kCFRunLoopDefaultMode);
        CFRelease(source);
        
        // 循环调用 runMode:beforeDate: 方法，实现线程保活。
        while ([_runLoop runMode:NSDefaultRunLoopMode beforeDate:[NSDate distantFuture]]) {

        }
        assert(NO);
    }
}

- (NSRunLoop *)runLoop;
{
    // 使用 dispatch_group_wait 等待 _runLoop 初始化完成。
    dispatch_group_wait(_waitGroup, DISPATCH_TIME_FOREVER);
    return _runLoop;
}

@end
