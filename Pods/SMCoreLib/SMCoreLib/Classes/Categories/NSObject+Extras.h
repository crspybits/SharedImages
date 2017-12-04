//
//  NSObject+Extras.h
//  Petunia
//
//  Created by Christopher Prince on 2/20/14.
//  Copyright (c) 2014 Spastic Muffin, LLC. All rights reserved.
//

#import <Foundation/Foundation.h>

// 5/11/15; For current code that needs TargetsAndSelectors, just include the following file. I've done the following import for backward compatibility.
#import "NSObject+TargetsAndSelectors.h"

@protocol Debounce <NSObject>

// The only reason I have made all of these optional is to avoid the compiler complaining. I'm using this protocol just to document the fact that I'm making these methods available (through the NSObject (Extras) category) in a particular class.
@optional

// Call this exactly once, before you assign to the blockToDebounce property.
// Give the interval as a negative value to use the default interval (see Debounce.h).
- (void) setupBlockDebounceWithInterval: (NSTimeInterval) intervalInSeconds;

// Assignments to this property are debounced in the same manner as in Debounce.h/.m for delay debounce.
@property (nonatomic, strong) void (^blockToDebounce)(void);

@end

@interface NSObject (Extras)<Debounce>

// When these are used, bridged to Swift, the Swift selector (function) must not be marked as private. See http://stackoverflow.com/questions/31084402/getting-a-functions-return-type-in-swift
// Enforce the rule that the selector used must return void.
- (void) performVoidReturnSelector:(SEL)aSelector withObject:(id)object;
- (void) performVoidReturnSelector:(SEL)aSelector;

// How many objects are referencing this object? (i.e., in ARC).
- (NSInteger) arcReferenceCount;

@end







