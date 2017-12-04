//
//  NSDate+Extras.m
//  Petunia
//
//  Created by Christopher Prince on 2/12/15.
//  Copyright (c) 2015 Spastic Muffin, LLC. All rights reserved.
//

#import "NSDate+Extras.h"

@implementation NSDate (Extras)

- (NSDate *) removeHMS;
{
    NSDateComponents *components = [[NSCalendar currentCalendar] components:NSDayCalendarUnit | NSMonthCalendarUnit | NSYearCalendarUnit fromDate:self];
    NSCalendar* cal = [NSCalendar currentCalendar];
    return [cal dateFromComponents:components];
};

- (BOOL) equalDMY: (NSDate *) date2;
{
    NSDateComponents *componentsDate1 = [[NSCalendar currentCalendar] components:NSDayCalendarUnit | NSMonthCalendarUnit | NSYearCalendarUnit fromDate:self];
    NSDateComponents *componentsDate2 = [[NSCalendar currentCalendar] components:NSDayCalendarUnit | NSMonthCalendarUnit | NSYearCalendarUnit fromDate:date2];
    
    if (componentsDate1.year == componentsDate2.year
        && componentsDate1.month == componentsDate2.month
        && componentsDate1.day == componentsDate2.day) {
        return YES;
    }
    else {
        return NO;
    }
}

- (NSString *) shortFormat;
{
    NSDateFormatter *dateFormatter = [NSDateFormatter new];
    [dateFormatter setTimeStyle:NSDateFormatterNoStyle];
    [dateFormatter setDateStyle:NSDateFormatterShortStyle];
    NSLocale *usLocale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US"];
    [dateFormatter setLocale:usLocale];
    return [dateFormatter stringFromDate:self];
}

// Return units are seconds (NSTimeInterval unit)
+ (NSTimeInterval) timeIntervalForWeeks: (double) weeks;
{
    return weeks * 7.0 * 24.0 * 60.0 * 60.0;
}

+ (NSTimeInterval) timeIntervalForDays: (double) days;
{
    return days * 24.0 * 60.0 * 60.0;
}

- (NSDate *) plusWeeks: (double) weeks;
{
    NSTimeInterval interval = [NSDate timeIntervalForWeeks:weeks];
    return [[NSDate alloc] initWithTimeInterval:interval sinceDate:self];
}

- (NSDate *) plusDays: (double) days;
{
    NSTimeInterval interval = [NSDate timeIntervalForDays:days];
    return [[NSDate alloc] initWithTimeInterval:interval sinceDate:self];
}

- (NSDate *) plusMinutes: (double) minutes;
{
    return [[NSDate alloc] initWithTimeInterval:minutes*60 sinceDate:self];
}

// See also http://stackoverflow.com/questions/5965044/how-to-compare-two-nsdates-which-is-more-recent

- (BOOL) withinRange: (NSDate *) startDate endDate:(NSDate *) endDate;
{
    NSComparisonResult result = [self compare:startDate];
    if (NSOrderedAscending == result) {
        // self is prior to startDate.
        return NO;
    }
    
    result = [self compare:endDate];
    if (NSOrderedDescending == result) {
        // self is after to startDate.
        return NO;
    }
    
    return YES;
}

// Returns true iff self < otherDate
- (BOOL) priorTo: (NSDate *) otherDate;
{
    NSComparisonResult result = [self compare:otherDate];
    if (NSOrderedAscending == result) {
        // self is prior to startDate.
        return YES;
    }
    
    return NO;
}

@end
