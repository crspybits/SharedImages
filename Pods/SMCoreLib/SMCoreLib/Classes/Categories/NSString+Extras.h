//
//  NSString+Extras.h
//  Petunia
//
//  Created by Christopher Prince on 5/1/13.
//  Copyright (c) 2013 Christopher Prince. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@interface NSString (Extras)

- (NSString *) trimWhiteSpace;

// Returns false when string is nil, or if string is @""
- (BOOL) hasContents;
- (BOOL) haveContents;

// Works even if one or both of the strings is nil.
// Two strings are equal if they are both nil.
+ (BOOL) stringIsEqual: (NSString *) string toOtherString: (NSString *) otherString;

- (BOOL) isEqualToStringIgnoreCase:(NSString *)aString;

// Comma Separated Value methods(CSV)

// If the listOfItems is nil, this returns nil.
+ (NSString *) convertToCSV: (NSArray *) listOfItems;

- (NSArray *) convertFromCSV;
- (NSString *) appendCSV: (NSString *) newCSV;
- (NSString *) removeItemFromCSV: (NSString *) itemToRemove;

// Because iOS7 made sizeWithFont:constrainedToSize: deprecated. Grrrr :(.
- (CGRect) boundingRectWithFont:(UIFont *) font constrainedToSize:(CGSize) contstraintSize lineBreakMode:(NSLineBreakMode) lineBreakMode;

@end
