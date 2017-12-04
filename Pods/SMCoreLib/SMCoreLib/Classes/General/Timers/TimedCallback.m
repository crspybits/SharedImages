//
//  TimedCallback.m
//  Petunia
//
//  Created by Christopher Prince on 11/24/13.
//  Copyright (c) 2013 Spastic Muffin, LLC. All rights reserved.
//

#import "TimedCallback.h"
#import "RepeatingTimer.h"
#import "SPASLog.h"

@interface TimedCallback()
@property (nonatomic, strong) void (^callback)(void);
@property (nonatomic, strong) RepeatingTimer *timer;
@end

@implementation TimedCallback

- (id) initWithDuration: (float) durationInSeconds andCallback: (void (^)(void)) callback {
    self = [super init];
    if (self) {
        SPASLog(@"durationInSeconds: %f", durationInSeconds);
        self.callback = callback;
        
        self.timer = [[RepeatingTimer alloc] initWithInterval:durationInSeconds selector:@selector(doCallback) andTarget:self];
        [self.timer start];
    }
    return self;
}

+ (TimedCallback *) withDuration: (float) durationInSeconds andCallback: (void (^)(void)) callback;
{
    return [[TimedCallback alloc] initWithDuration:durationInSeconds andCallback:callback];
}

- (void) doCallback {
    [self.timer cancel];
    self.callback();
    [self cleanup];
}

- (void) cancel;
{
    [self.timer cancel];
    [self cleanup];
}

// 12/9/14; Trying to deal with memory leak.
- (void) cleanup;
{
    self.callback = nil;
    self.timer = nil;
}

@end
