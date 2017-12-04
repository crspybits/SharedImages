//
//  TimedCallback.h
//  Petunia
//
//  Created by Christopher Prince on 11/24/13.
//  Copyright (c) 2013 Spastic Muffin, LLC. All rights reserved.
//

// If you are using this from Swift, make sure to inherit from NSObject. See RepeatingTimer.

#import <Foundation/Foundation.h>

@interface TimedCallback : NSObject

- (id) initWithDuration: (float) durationInSeconds andCallback: (void (^)(void)) callback;

// You don't have to keep a reference to the returned object. Keep a reference only if you want to cancel the timed callback.
+ (TimedCallback *) withDuration: (float) durationInSeconds andCallback: (void (^)(void)) callback;

- (void) cancel;

@end
