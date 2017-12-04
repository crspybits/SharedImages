//
//  NSDate+Extras.h
//  Petunia
//
//  Created by Christopher Prince on 2/12/15.
//  Copyright (c) 2015 Spastic Muffin, LLC. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSDate (Extras)

// Zeros out components of the date aside from month, day, year.
- (NSDate *) removeHMS;

// Do self and otherDate have the same d/m/y?
- (BOOL) equalDMY: (NSDate *) otherDate;

// Get date formatted in short format, e.g., D/M/Y. Doesn't give time.
- (NSString *) shortFormat;

// Returns self plus a given number of weeks, days, or minutes. Give weeks/days/minutes as a negative to subtract.
- (NSDate *) plusWeeks: (double) weeks;
- (NSDate *) plusDays: (double) days;
- (NSDate *) plusMinutes: (double) minutes;

// Returns true iff (startDate <= self and self <= endDate)
- (BOOL) withinRange: (NSDate *) startDate endDate:(NSDate *) endDate;

// Returns true iff self < otherDate
- (BOOL) priorTo: (NSDate *) otherDate;

@end
