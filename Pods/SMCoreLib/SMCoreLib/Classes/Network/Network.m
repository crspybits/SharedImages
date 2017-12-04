//
//  Network.m
//  Petunia
//
//  Created by Christopher Prince on 9/7/13.
//  Copyright (c) 2013 Spastic Muffin, LLC. All rights reserved.
//

#import "Network.h"
@import Reachability;
#import "SPASLog.h"
#import "NSObject+Extras.h"

//#import "AFNetworkReachabilityManager.h"

@interface Network()
@property (nonatomic, strong) Reachability *reach;
@property (nonatomic, strong) void (^reachableBlock)(BOOL networkIsConnected);
@property (nonatomic, readwrite) NSObject<TargetsAndSelectors> *connectionStateCallbacks;
@property (nonatomic) BOOL previousNetworkIsReachable;
@property (nonatomic) BOOL calledOnce;
@end

@implementation Network

+ (instancetype) session;
{
    static Network* s_sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        s_sharedInstance = [self new];
        
        /*
        // TESTING
        [[AFNetworkReachabilityManager sharedManager] setReachabilityStatusChangeBlock:^(AFNetworkReachabilityStatus status) {
            NSLog(@"AFNetworkReachabilityManager: %@", AFStringFromNetworkReachabilityStatus(status));
        }];
        [[AFNetworkReachabilityManager sharedManager] startMonitoring];
        */
        
        s_sharedInstance.previousNetworkIsReachable = NO;
        s_sharedInstance.calledOnce = NO;
        
        s_sharedInstance.connectionStateCallbacks = [NSObject new];
        [s_sharedInstance.connectionStateCallbacks resetTargets];
        
        s_sharedInstance.reach = [Reachability reachabilityWithHostname:@"www.google.com"];
        s_sharedInstance.reach.reachableBlock = ^(Reachability * reachability)
        {
            dispatch_async(dispatch_get_main_queue(), ^{
                [s_sharedInstance callReachableHandlers:YES];
            });
        };
        
        s_sharedInstance.reach.unreachableBlock = ^(Reachability * reachability)
        {
            dispatch_async(dispatch_get_main_queue(), ^{
                [s_sharedInstance callReachableHandlers:NO];
            });
        };
        
        [s_sharedInstance.reach startNotifier];
    });
    
    return s_sharedInstance;
}

- (void) callReachableHandlers: (BOOL) currentNetworkIsReachable;
{
    SPASLog(@"Network.initializeClass: Network is reachable: %d", currentNetworkIsReachable);
    
    // 1/3/16; I'm going to change this so that it only calls its handlers if there is actually a change in reachability, i.e., from reachable to unreachable or vice versa.
    
    if (self.previousNetworkIsReachable == currentNetworkIsReachable && self.calledOnce) {
        // No change.
        return;
    }
    
    SPASLog(@"Network.initializeClass: Network reachability changed");
    
    self.calledOnce = YES;
    self.previousNetworkIsReachable = currentNetworkIsReachable;
    
    if (self.reachableBlock) {
        self.reachableBlock(currentNetworkIsReachable);
    }
    
    [self.connectionStateCallbacks forEachTargetInCallbacksDo:^(id target, SEL selector, NSMutableDictionary *dict) {
        [target performVoidReturnSelector:selector];
    }];
}

- (void) appStartup;
{
    // Does nothing really. Just makes sure we're initialized.
    (void) [Network session];
}

- (void) restart;
{
    [self.reach stopNotifier];
    [self.reach startNotifier];
}

- (void) detectWhenConnected: (void (^)(BOOL networkIsConnected)) block {
    self.reachableBlock = block;
}

- (BOOL) connected {
#ifdef DEBUG
    if (self.debugNetworkOff) return NO;
#endif
    return self.reach.isReachable;
}

+ (BOOL) connected;
{
#ifdef DEBUG
    if ([Network session].debugNetworkOff) return NO;
#endif
    return [Network session].connected;
}

#ifdef DEBUG
- (void) setDebugNetworkOff:(BOOL)debugNetworkOff;
{
    _debugNetworkOff = debugNetworkOff;
    if (_debugNetworkOff) {
        [self callReachableHandlers:NO];
    }
    else {
        [self callReachableHandlers:self.connected];
    }
}
#endif

@end
