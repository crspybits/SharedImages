//
//  Debounce.m
//  Petunia
//
//  Created by Christopher Prince on 9/12/14.
//  Copyright (c) 2014 Spastic Muffin, LLC. All rights reserved.
//

#import "Debounce.h"
#import "RepeatingTimer.h"
#import "SMAssert.h"

@interface Debounce()
@property (nonatomic, strong) RepeatingTimer *timer;
@property (nonatomic) DebounceType debounceType;

// DebounceTypeDelay
@property (nonatomic, strong) void (^lastBlock)(void);

// DebounceTypeImmediate
@property (nonatomic) BOOL doneImmediate;
@end

@implementation Debounce

- (void) setupTimer;
{
    __weak Debounce *weakSelf = self;
    self.timer = [[RepeatingTimer alloc] initWithInterval:DEFAULT_DEBOUNCE_INTERVAL selector:@selector(timerExpired:) andTarget:weakSelf];
}

- (instancetype) initWithType: (DebounceType) debounceType;
{
    self = [super init];
    if (self) {
        self.debounceType = debounceType;
        _interval = DEFAULT_DEBOUNCE_INTERVAL;

        __weak Debounce *weakSelf = self;
        self.timer = [[RepeatingTimer alloc] initWithInterval:DEFAULT_DEBOUNCE_INTERVAL selector:@selector(timerExpired:) andTarget:weakSelf];
        [self.timer cancel]; // We don't need it started yet.
    }
    
    return self;
}

- (void) dealloc;
{
    SPASLogDetail(@"dealloc");
}

- (void) setInterval:(NSTimeInterval)interval
{
    _interval = interval;
    self.timer.interval = interval;
}

- (void) queueBlock: (void (^)(void)) block;
{
    AssertIf(!block, @"Yikes, nil block");
    
    void (^restart)() = ^{
        if (self.timer.running) {
            [self.timer cancel];
        }
        [self.timer start];
    };
    
    @synchronized(self) {
        switch (self.debounceType) {
            case DebounceTypeDelay:
                restart();
                
                self.lastBlock = block;
                break;
                
            case DebounceTypeImmediate:
                restart();
                
                if (self.doneImmediate) {
                    // We're within the time interval. We have already executed the first block. Have, just above, reset the timer. So, we're going to ignore this block.
                    SPASLogDetail(@"Ignoring block: %@", block);
                } else {
                    // Outside of interval. Starting afresh.
                    self.doneImmediate = YES;
                    block();
                }
                break;
                
            case DebounceTypeDuration:
                if (!self.lastBlock) {
                    restart();
                }
                
                self.lastBlock = block;
                break;
        }
    }
}

- (void) timerExpired: (id) sender;
{
    SPASLog(@"timerExpired: %@", self);
    
    @synchronized(self) {
        [self.timer cancel];
        
        switch (self.debounceType) {
            case DebounceTypeDelay:
            case DebounceTypeDuration:
                self.lastBlock();
                
                // I see no reason to still keep a reference.
                self.lastBlock = nil;
                break;
                
            case DebounceTypeImmediate:
                self.doneImmediate = NO;
                break;
        }
    }
}

- (void) cancel;
{
    [self.timer cancel];
    self.lastBlock = nil;
}

- (void) destroy;
{
    [self.timer destroy];
}

@end
