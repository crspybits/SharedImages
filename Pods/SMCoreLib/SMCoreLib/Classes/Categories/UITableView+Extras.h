//
//  UITableView+Extras.h
//  Petunia
//
//  Created by Christopher Prince on 8/28/14.
//  Copyright (c) 2014 Spastic Muffin, LLC. All rights reserved.
//

#import <UIKit/UIKit.h>

// In seconds.
#define DEFAULT_DURATION_OF_FLASH 2.0

@interface UITableView (Extras)

/**
 *  Give a negative value for durationOfFlash if you want to use the default. Give a value of 0.0 for duration if you want to use Apple's duration (looks OK on iOS6).
 */
- (void) flashRow: (NSUInteger) rowNumber withDuration: (NSTimeInterval) durationOfFlash;

- (void) flashRow: (NSUInteger) rowNumber withDuration: (NSTimeInterval) durationOfFlash andCompletion: (void (^)(void)) callback;

// For iOS7 and iOS8
// For iOS8, you also need to use the corresponding UITableViewCell category method in cellForRowAtIndexPath:
- (void) makeFullLengthSeparator;

@end
