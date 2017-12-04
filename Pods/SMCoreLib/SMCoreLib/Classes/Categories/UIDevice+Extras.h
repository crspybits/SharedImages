//
//  UIDevice+Extras.h
//  WhatDidILike
//
//  Created by Christopher Prince on 10/6/14.
//  Copyright (c) 2014 Spastic Muffin, LLC. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface UIDevice (Extras)

+ (BOOL) ios6OrEarlier;

+ (BOOL) ios7OrLater;
+ (BOOL) ios7OrEarlier;

// Any subversion of iOS7
+ (BOOL) iOS7;

+ (BOOL) iOS8OrLater;
+ (BOOL) ios8OrEarlier;

+ (BOOL) iOS9OrLater;

/**
 *  Returns a float such as 7.11 (for 7.1.1) or 6.0
 */
+ (float) iosVersion;

// device model and make
+ (NSString *) machineName;

+ (BOOL) isPhone;
+ (BOOL) isPad;

// Force the device into the particular orientation. E.g., so we can open a VC that only uses a particular orientation. The implementation of this is a HACK!!!
+ (void) forceIntoOrientation: (UIInterfaceOrientation) orientation;

@property (nonatomic, readonly) BOOL orientationIsLandscape;
@property (nonatomic, readonly) BOOL orientationIsPortrait;

// Is app attached to debugger? Returns NO if this is a production build. See SO link in code.
+ (BOOL) beingDebugged;

@end
