//
//  NSThread+Extras.m
//  SMCoreLib
//
//  Created by Christopher Prince on 2/14/16.
//  Copyright © 2016 Spastic Muffin, LLC. All rights reserved.
//

#import "NSThread+Extras.h"

@implementation NSThread (Extras)

+ (void) runSyncOnMainThread: (dispatch_block_t) block;
{
    if ([NSThread isMainThread]) {
        block();
    } else {
        dispatch_sync(dispatch_get_main_queue(), block);
    }
}

@end
