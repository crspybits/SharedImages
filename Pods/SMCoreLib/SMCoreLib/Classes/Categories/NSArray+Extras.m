//
//  NSArray+Extras.m
//  Petunia
//
//  Created by Christopher Prince on 8/19/14.
//  Copyright (c) 2014 Spastic Muffin, LLC. All rights reserved.
//

#import "NSArray+Extras.h"
#import "SPASLog.h"
#import "SMAssert.h"

@implementation NSArray (Extras)

// See also http://stackoverflow.com/questions/17109942/how-can-i-most-easily-flatten-a-three-dimensional-array-in-cocoa/29548683#29548683

- (NSArray *) flatten;
{
    NSMutableArray *flattedArray = [NSMutableArray new];
    
    for (id item in self) {
        if ([[item class] isSubclassOfClass:[NSArray class]]) {
            [flattedArray addObjectsFromArray:[item flatten]];
        } else {
            [flattedArray addObject:item];
        }
    }
    
    return flattedArray;
}

- (NSArray *) tail;
{
    NSMutableArray *copyOfArray = [self mutableCopy];
    [copyOfArray removeObjectAtIndex:0];
    return copyOfArray;
}

#ifdef DEBUG
+ (void) unitTests;
{
    NSArray *flattenedArray;

    NSArray *initialArray1 = @[@[@23, @354, @1, @[@7], @[@[@3]]], @[@[@890], @2, @[@[@6], @8]]];
    NSArray *expectedArray1 = @[@23, @354, @1, @7, @3, @890, @2, @6, @8];
    flattenedArray = [initialArray1 flatten];
    SPASLogDetail(@"flattenedArray: %@", flattenedArray);
    AssertIf(![flattenedArray isEqualToArray:expectedArray1], @"Arrays are not equal");
    
    NSArray *initialArray2 = @[@[@23, @354, @1, [@[@7] mutableCopy], @[@[@3]]], @[[@[@890] mutableCopy], @2, @[@[@6], @8]]];
    NSArray *expectedArray2 = expectedArray1;
    flattenedArray = [initialArray2 flatten];
    SPASLogDetail(@"flattenedArray: %@", flattenedArray);
    AssertIf(![flattenedArray isEqualToArray:expectedArray2], @"Arrays are not equal");
}
#endif

@end
