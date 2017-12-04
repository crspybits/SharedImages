//
//  CallCounter.h
//  Petunia
//
//  Created by Christopher Prince on 10/8/14.
//  Copyright (c) 2014 Spastic Muffin, LLC. All rights reserved.
//

// This class enables you call a method in a delayed manner, across possible launches of the app. This can be used, for example, to call a method when an app has been launched N times.

#import <Foundation/Foundation.h>

@interface CallCounter : NSObject

// This method has two effects depending on when it is salled: 1) The first time this is called (and the counting spans launches of your app), the nsUserDefaultsKey is used to store data in NSUserDefaults, 2) The 2nd, 3rd etc. time it is called with this key, it counts the number of times it is called until when it is called numberOfTimes (again, spanning launches of your app), the selector given is invoked on the object given. Once. It will not be called again unless you call the reset method.
+ (void) withKey: (NSString *) nsUserDefaultsKey numberOfTimes: (NSUInteger) numberOfTimes target: (SEL) selector andObject: (NSObject<NSCoding> *)dataObject;

// This has the same effect as the 2nd, 3rd, etc. time the withKey:numberOfTimes:target:andObject: method is called. This method has no effect if the corresponding call to withKey:numberOfTimes:target:andObject: has not been made.
+ (void) callWithKey: (NSString *) nsUserDefaultsKey;

+ (void) resetKey: (NSString *) nsUserDefaultsKey;

@end
