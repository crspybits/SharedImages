//
//  Debounce.h
//  Petunia
//
//  Created by Christopher Prince on 9/12/14.
//  Copyright (c) 2014 Spastic Muffin, LLC. All rights reserved.
//

// Waits for interval seconds before executing the block. Only the last block is executed, the others are discarded. For example, within an initial 2 seconds, suppose that two queueBlock calls were made. Then, 3 seconds after the second call is made, the second block is executed, and the first is discarded.

#import <Foundation/Foundation.h>

@interface Debounce : NSObject

typedef NS_ENUM(NSInteger, DebounceType) {
    // As above. Execution is done *after* interval.
    DebounceTypeDelay,
    
    // Reversed. The first block is executed *immediately*. Further calls within interval time are discarded.
    DebounceTypeImmediate,
    
    // After queuing blocks for interval duration, the last block is executed.
    DebounceTypeDuration,
};

// Designated initializer
- (instancetype) initWithType: (DebounceType) debounceType;

// In seconds.
#define DEFAULT_DEBOUNCE_INTERVAL 3.0
@property (nonatomic) NSTimeInterval interval;

- (void) queueBlock: (void (^)(void)) block;

- (void) cancel;

- (void) destroy;

@end
