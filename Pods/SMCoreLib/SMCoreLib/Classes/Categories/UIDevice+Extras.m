//
//  UIDevice+Extras.m
//  WhatDidILike
//
//  Created by Christopher Prince on 10/6/14.
//  Copyright (c) 2014 Spastic Muffin, LLC. All rights reserved.
//

#import "UIDevice+Extras.h"
#import <sys/utsname.h>
#include <assert.h>
#include <stdbool.h>
#include <sys/types.h>
#include <unistd.h>
#include <sys/sysctl.h>

@implementation UIDevice (Extras)

// For a different technique see: http://stackoverflow.com/questions/18837388/respondstoselector-but-the-selector-is-unrecognized
+ (BOOL) ios7OrLater {
    BOOL ios7OrLater = YES;
    if (floor(NSFoundationVersionNumber) <= NSFoundationVersionNumber_iOS_6_1) {
        ios7OrLater = NO;
    }
    
    return ios7OrLater;
}

+ (BOOL) ios6OrEarlier {
    if ([self iosVersion] < 7.0) return YES;
    return NO;
}

+ (BOOL) ios7OrEarlier;
{
    if ([self iosVersion] < 8.0) return YES;
    return NO;
}

+ (BOOL) iOS7;
{
    return [self isSpecificVersion:7];
}

+ (BOOL) iOS8OrLater;
{
    if ([self iosVersion] >= 8.0) return YES;
    return NO;
}

+ (BOOL) ios8OrEarlier;
{
    if ([self iosVersion] < 9.0) return YES;
    return NO;
}

+ (BOOL) iOS9OrLater;
{
    if ([self iosVersion] >= 9.0) return YES;
    return NO;
}

+ (BOOL) isSpecificVersion: (NSUInteger) specificVersion;
{
    float version = [self iosVersion];
    if ((version >= specificVersion) && (version < specificVersion+1)) return YES;
    return NO;
}

+ (float) iosVersion;
{
    NSString *osVersion = [[UIDevice currentDevice] systemVersion];
    NSArray* numbers = [osVersion componentsSeparatedByString:@"."];
    
    // If they give us something like "7.1.1", this will convert that number to 7.11.
    // We assume that they give us at least "X.Y".
    NSAssert([numbers count] >= 2, @"Didn't get at least two values");
    
    NSMutableString *floatString = [NSMutableString new];
    [floatString appendFormat:@"%@.%@", numbers[0], numbers[1]];
    if ([numbers count] > 2) {
        [floatString appendString:numbers[2]];
    }
    
    return [floatString floatValue];
}

// See http://stackoverflow.com/questions/11197509/ios-iphone-get-device-model-and-make
+ (NSString *) machineName;
{
    struct utsname systemInfo;
    uname(&systemInfo);
    
    return [NSString stringWithCString:systemInfo.machine
                              encoding:NSUTF8StringEncoding];
}

- (BOOL) orientationIsLandscape;
{
    switch ([UIDevice currentDevice].orientation) {
        case UIDeviceOrientationUnknown:
        case UIDeviceOrientationFaceUp:
        case UIDeviceOrientationFaceDown:
        case UIDeviceOrientationPortrait:
        case UIDeviceOrientationPortraitUpsideDown:
            return NO;
            
        case UIDeviceOrientationLandscapeLeft:
        case UIDeviceOrientationLandscapeRight:
            return YES;
    }
}

- (BOOL) orientationIsPortrait;
{
    return !self.orientationIsLandscape;
}

+ (BOOL) isPhone;
{
    return (UI_USER_INTERFACE_IDIOM()==UIUserInterfaceIdiomPhone);
}

+ (BOOL) isPad;
{
    return !self.isPhone;
}

// HACK!!!!
// See http://stackoverflow.com/questions/26357162/how-to-force-view-controller-orientation-in-ios-8
+ (void) forceIntoOrientation: (UIInterfaceOrientation) orientation;
{
    [[UIDevice currentDevice] setValue: @(orientation) forKey:@"orientation"];
}

// Modified from http://stackoverflow.com/questions/4744826/detecting-if-ios-app-is-run-in-debugger
+ (BOOL) beingDebugged;
{
    // Returns true if the current process is being debugged (either
    // running under the debugger or has a debugger attached post facto).
    int                 junk;
    int                 mib[4];
    struct kinfo_proc   info;
    size_t              size;
    
    // Do we have a production build?
    #ifndef DEBUG
        return NO;
    #endif
    
    // Initialize the flags so that, if sysctl fails for some bizarre 
    // reason, we get a predictable result.

    info.kp_proc.p_flag = 0;

    // Initialize mib, which tells sysctl the info we want, in this case
    // we're looking for information about a specific process ID.

    mib[0] = CTL_KERN;
    mib[1] = KERN_PROC;
    mib[2] = KERN_PROC_PID;
    mib[3] = getpid();

    // Call sysctl.

    size = sizeof(info);
    junk = sysctl(mib, sizeof(mib) / sizeof(*mib), &info, &size, NULL, 0);
    assert(junk == 0);

    // We're being debugged if the P_TRACED flag is set.

    return ( (info.kp_proc.p_flag & P_TRACED) != 0 );
}

@end
