//
//  NSObject+TargetsAndSelectors.h
//  Petunia
//
//  Created by Christopher Prince on 5/11/15.
//  Copyright (c) 2015 Spastic Muffin, LLC. All rights reserved.
//

#import <Foundation/Foundation.h>

// Allow an object to have a collection of target's, and selectors that can be called as needed.

@protocol TargetsAndSelectors <NSObject>

// The only reason I have made all of these optional is to avoid the compiler complaining. I'm using this protocol just to document the fact that I'm making these methods available (through the NSObject (TargetsAndSelectors) category) in a particular class.
@optional

// Clear all target/selector's. This method must be called *before* any call to addTarget or to other methods of this category, for a particular instance.
- (void) resetTargets;

/**
 *  Add/remove a callback.
 *  When this is used, bridged to Swift, the Swift selector (function) must not be marked as private. See http://stackoverflow.com/questions/31084402/getting-a-functions-return-type-in-swift
 *
 *  @param target Target object.
 *  @param selector Method to call on the target object.
 *
 *  @return Dictionary that was just added to the callbacks property for this target and selector.
 */
- (NSMutableDictionary *) addTarget: (id) target withSelector: (SEL) selector;
- (void) removeTarget: (id) target withSelector: (SEL) selector;

/**
 *  Convenience method to enable calling each of the callbacks in sequence.
 */
- (void) forEachTargetInCallbacksDo: (void (^)(id target, SEL selector, NSMutableDictionary *dict)) block;

// Elements are NSMutableDictionary's, with keys:
// Value of this is a target (id) embedded in a WeakRef object, so that if the target is deallocated, we don't retain a reference that object.
#define TARGETS_KEY_WEAK_TARGET @"weakTarget"
// Value of this is formatted as an NSString
#define TARGETS_KEY_SELECTOR @"selector"
@property (nonatomic, strong, readonly) NSArray *callbacks;

@end

@interface NSObject (TargetsAndSelectors)<TargetsAndSelectors>
@end
