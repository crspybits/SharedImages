//
//  Network.h
//  Petunia
//
//  Created by Christopher Prince on 9/7/13.
//  Copyright (c) 2013 Spastic Muffin, LLC. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "NSObject+TargetsAndSelectors.h"

@interface Network : NSObject

+ (instancetype) session;

- (void) appStartup;

// Assumes initializeClass has been called previously. There may be some latency between calling initializeClass and the correct value being returned by this method.
- (BOOL) connected;
+ (BOOL) connected;

// The given block will be called when the network changes state from connected to disconnected, or from disconnected to connected.
- (void) detectWhenConnected: (void (^)(BOOL networkIsConnected)) block;

// When the network connection state changes, these callbacks, if any, will be called.
// In Swift, callback objects must be derived from NSObject.
@property (nonatomic, readonly) NSObject<TargetsAndSelectors> *connectionStateCallbacks;

// Cause the callback to be called based on the current network state.
- (void) restart;

#ifdef DEBUG
// Setting this to YES simulates turning the network off in terms of the properties and methods of this class.
@property (nonatomic) BOOL debugNetworkOff;
#endif

@end
