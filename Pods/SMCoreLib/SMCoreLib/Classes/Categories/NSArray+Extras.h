//
//  NSArray+Extras.h
//  Petunia
//
//  Created by Christopher Prince on 8/19/14.
//  Copyright (c) 2014 Spastic Muffin, LLC. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSArray (Extras)

// Given that self is an nested series of arrays, returns self without the nested structure.
- (NSArray *) flatten;

// Return all but the 0th element
- (NSArray *) tail;

#ifdef DEBUG
+ (void) unitTests;
#endif

@end
