//
//  NSString+Extras.m
//  Petunia
//
//  Created by Christopher Prince on 5/1/13.
//  Copyright (c) 2013 Christopher Prince. All rights reserved.
//

#import "NSString+Extras.h"

@implementation NSString (Extras)

- (NSString *) trimWhiteSpace {
    return [self stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
}

- (BOOL) hasContents {
    return ((self) && ([self length] > 0));
}

- (BOOL) haveContents {
    return [self hasContents];
}

+ (BOOL) stringIsEqual: (NSString *) string toOtherString: (NSString *) otherString {
    // Equal if both are nil.
    if ((! string) && (!otherString)) return YES;
    
    // If one is empty and the other is nil, they are equal
    if ([string isEqualToString:@""] && (! otherString)) return YES;
    if ([otherString isEqualToString:@""] && (! string)) return YES;
    
    // Not equal if only one is nil. The other will not be empty at this point.
    if ((! string) || (! otherString)) return NO;
    
    // Neither is nil, return regular compare.
    return [string isEqualToString:otherString];
}

- (BOOL) isEqualToStringIgnoreCase:(NSString *)aString {
    NSComparisonResult result = [self caseInsensitiveCompare:aString];
    if (NSOrderedSame == result) {
        return YES;
    }
    return NO;
}

+ (NSString *) convertToCSV: (NSArray *) listOfItems;
{
    if ([listOfItems count] == 0) {
        return nil;
    }
    
    NSMutableString *result = [NSMutableString new];
    for (NSString *item in listOfItems) {
        if ([result length] != 0) {
            [result appendString:@","];
        }
        [result appendString:item];
    }
    return result;
}

- (NSArray *) convertFromCSV;
{
    NSArray *result = nil;
    if ([[self trimWhiteSpace] length] > 0) {
        result = [self componentsSeparatedByCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@","]];
    }
    return result;
}

- (NSString *) appendCSV: (NSString *) newCSV;
{
    NSMutableString *result = [NSMutableString new];
    
    if ([self length]) {
        [result appendString:self];
    }
    
    if ([newCSV length]) {
        if ([result length]) {
            [result appendString:@","];
        }
        [result appendString:newCSV];
    }
    
    if ([result length]) {
        return result;
    }
    
    return nil;
}

- (NSString *) removeItemFromCSV: (NSString *) itemToRemove;
{
    NSMutableArray *csvArray = [[self convertFromCSV] mutableCopy];
    [csvArray removeObject:itemToRemove];
    return [NSString convertToCSV:csvArray];
}

// Adapted from http://stackoverflow.com/questions/18897896/replacement-for-deprecated-sizewithfont-in-ios-7
- (CGRect) boundingRectWithFont:(UIFont *) font constrainedToSize:(CGSize) constraintSize lineBreakMode:(NSLineBreakMode) lineBreakMode;
{
    // set paragraph style
    NSMutableParagraphStyle *style = [[NSParagraphStyle defaultParagraphStyle] mutableCopy];
    [style setLineBreakMode:lineBreakMode];
    
    // make dictionary of attributes with paragraph style
    NSDictionary *sizeAttributes = @{NSFontAttributeName:font, NSParagraphStyleAttributeName: style};
    
    CGRect frame = [self boundingRectWithSize:constraintSize options:NSStringDrawingUsesLineFragmentOrigin attributes:sizeAttributes context:nil];
    
    /*
    // OLD
    CGSize stringSize = [self sizeWithFont:font
                              constrainedToSize:constraintSize
                                  lineBreakMode:lineBreakMode];
    // OLD
    */
    
    return frame;
}

@end
