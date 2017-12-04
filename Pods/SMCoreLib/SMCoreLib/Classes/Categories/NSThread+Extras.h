//
//  NSThread+Extras.h
//  SMCoreLib
//
//  Created by Christopher Prince on 2/14/16.
//  Copyright © 2016 Spastic Muffin, LLC. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSThread (Extras)

// Executes on main thread in a sync (not async) manner.
// This specifically checks if we're on the main queue already. Don't try to dispatch to the main queue if we're running on that already. Seems to cause a deadlock. See http://stackoverflow.com/questions/10984732/why-cant-we-use-a-dispatch-sync-on-the-current-queue
+ (void) runSyncOnMainThread: (dispatch_block_t) block;

@end
