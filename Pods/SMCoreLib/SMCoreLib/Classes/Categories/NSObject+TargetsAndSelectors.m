//
//  NSObject+TargetsAndSelectors.m
//  Petunia
//
//  Created by Christopher Prince on 5/11/15.
//  Copyright (c) 2015 Spastic Muffin, LLC. All rights reserved.
//

#import "NSObject+TargetsAndSelectors.h"
#import <objc/runtime.h>
#import "WeakRef.h"

@implementation NSObject (TargetsAndSelectors)

static char kCallbacksKey;

- (void) setCallbacks:(NSArray *)callbacks
{
    objc_setAssociatedObject(self, &kCallbacksKey, callbacks, OBJC_ASSOCIATION_RETAIN);
}

- (NSArray *) callbacks
{
    NSArray *theCallbacks = (NSArray *) objc_getAssociatedObject(self, &kCallbacksKey);
    return theCallbacks;
}

- (void) resetTargets
{
    self.callbacks = [NSMutableArray new];
}

- (NSMutableArray *) mutableCallbacks
{
    NSMutableArray *mutableCallbacks = (NSMutableArray *) self.callbacks;
    return mutableCallbacks;
}

- (NSMutableDictionary *) addTarget: (id) target withSelector: (SEL) selector;
{
    WeakRef *weakTarget = [WeakRef toObj:target];
    
    NSMutableDictionary *dict = [@{TARGETS_KEY_WEAK_TARGET: weakTarget,
                                   TARGETS_KEY_SELECTOR: NSStringFromSelector(selector)} mutableCopy];
    [[self mutableCallbacks] addObject:dict];
    return dict;
}

- (void) removeTarget: (id) target withSelector: (SEL) selector;
{
    NSString *stringSelector = NSStringFromSelector(selector);
    NSDictionary *dictToRemove = nil;
    
    for (NSDictionary *dict in [self mutableCallbacks]) {
        NSString *dictSelectorString = dict[TARGETS_KEY_SELECTOR];
        WeakRef *weakTarget = dict[TARGETS_KEY_WEAK_TARGET];
        if (weakTarget.obj == target && [dictSelectorString isEqualToString:stringSelector]) {
            dictToRemove = dict;
            break;
        }
    }
    
    if (dictToRemove) {
        [[self mutableCallbacks] removeObject:dictToRemove];
    }
}

- (void) forEachTargetInCallbacksDo: (void (^)(id target, SEL selector, NSMutableDictionary *dict)) block;
{
    // 5/10/15; Making a copy of the callbacks array in case one of the callbacks calls removeTarget above.
    NSArray *copyOfCallbacks = [self.callbacks copy];
    
    for (NSMutableDictionary *dict in copyOfCallbacks) {
        NSString *dictSelectorString = dict[TARGETS_KEY_SELECTOR];
        SEL selector = NSSelectorFromString(dictSelectorString);
        
        WeakRef *weakTarget = dict[TARGETS_KEY_WEAK_TARGET];
        
        // Going to just skip by any target that is nil, i.e., has been deallocated. A better idea would be to remove that target from the array...
        if (weakTarget.obj) {
            block(weakTarget.obj, selector, dict);
        }
    }
}

@end
