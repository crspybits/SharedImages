//
//  RepeatingTimer.m
//  Petunia
//
//  Created by Christopher Prince on 11/16/13.
//  Copyright (c) 2013 Spastic Muffin, LLC. All rights reserved.
//

#import "RepeatingTimer.h"
#import "SPASLog.h"
#import "NSThread+Extras.h"

@interface RepeatingTimer()
@property (nonatomic, strong) NSTimer *timer;
@property (nonatomic, strong) NSInvocation * invocation;
@end

@implementation RepeatingTimer

- (id) initWithInterval: (float) intervalInSeconds selector: (SEL) selector andTarget: (id) target {
    self = [super init];
    if (self) {
        // SPASLog(@"Constructor");
        NSMethodSignature * mySignature =
            [target methodSignatureForSelector:selector];
        self.invocation = [NSInvocation invocationWithMethodSignature:mySignature];
        [self.invocation setTarget:target];
        [self.invocation setSelector:selector];
        self.interval = intervalInSeconds;
    }
    return self;
}

- (BOOL) running {
    if (self.timer) return YES;
    return NO;
}

- (void) dealloc;
{
    // SPASLogDetail(@"dealloc");
}

- (void) start {
    if (!self.timer) {
        // SPASLog(@"start");
        // 2/13/16; Just found a bug here. When I created a timer from a MultipeerConnectivity delegate (specificially, from my SMMultiPeer.swift), the timer callback would not get called. Adding the timer to the runloop didn't work. I had to dispatch it to the main thread.
        // See also http://stackoverflow.com/questions/9918103/nstimer-requiring-me-to-add-it-to-a-runloop/35386962#35386962
        
        [NSThread runSyncOnMainThread:^{
            // SPASLog(@"start: On main queue");
            self.timer = [NSTimer scheduledTimerWithTimeInterval:self.interval  invocation: self.invocation repeats:YES];
        }];

        //NSRunLoop *runLoop = [NSRunLoop currentRunLoop];
        //[runLoop addTimer:self.timer forMode:NSDefaultRunLoopMode];
    }
}

- (void) cancel {
    // SPASLog(@"cancel");

    // "Calling this method requests the removal of the timer from the current run loop; as a result, you should always call the invalidate method from the same thread on which the timer was installed." (https://developer.apple.com/library/mac/documentation/Cocoa/Reference/Foundation/Classes/NSTimer_Class/)
    
    [NSThread runSyncOnMainThread:^{
        // SPASLog(@"cancel: On main queue");
        [self.timer invalidate];
        self.timer = nil;
    }];
}

- (void) destroy;
{
    [self cancel];
    
    // I'm not sure why, but without doing this, the RepeatingTimer gets retained.
    self.invocation = nil;
}

@end
