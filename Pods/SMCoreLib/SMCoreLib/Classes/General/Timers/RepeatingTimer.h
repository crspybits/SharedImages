//
//  RepeatingTimer.h
//  Petunia
//
//  Created by Christopher Prince on 11/16/13.
//  Copyright (c) 2013 Spastic Muffin, LLC. All rights reserved.
//

/* If you are using this from Swift, make sure to inherit from NSObject. Was getting this error, otherwise:
2015-12-12 18:49:07.742 NetDb[1863:1180054] *** NSForwarding: warning: object 0x127770d00 of class 'NetDb.SMCloudFiles' does not implement methodSignatureForSelector: -- trouble ahead
Unrecognized selector -[NetDb.SMCloudFiles methodSignatureForSelector:]
*/
#import <Foundation/Foundation.h>

@interface RepeatingTimer : NSObject

// Designated initializer. The selector has no arguments. When first created, a timer is not running.
- (id) initWithInterval: (float) intervalInSeconds selector: (SEL) selector andTarget: (id) target;

// If already started, has no effect.
- (void) start;

// Can be restarted.
- (void) cancel;

// Cancels, but cannot be restarted.
// You must call this, or the RepeatingTimer will get retained.
- (void) destroy;

// To change the time interval.
@property (nonatomic) NSTimeInterval interval;

// YES if started but not cancelled. NO after calling init method.
@property (nonatomic, readonly) BOOL running;
@end
