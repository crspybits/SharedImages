//
//  NSObject+Extras.m
//  Petunia
//
//  Created by Christopher Prince on 2/20/14.
//  Copyright (c) 2014 Spastic Muffin, LLC. All rights reserved.
//

#import "NSObject+Extras.h"
#import <objc/runtime.h>
#import "Debounce.h"
#import "SMAssert.h"

@implementation NSObject (Extras)

// Apparently the reason the regular performSelect gives a compile time warning is that the system doesn't know the return type. I'm going to (a) make sure that the return type is void, and (b) disable this warning
// See http://stackoverflow.com/questions/7017281/performselector-may-cause-a-leak-because-its-selector-is-unknown

- (void) checkSelector:(SEL)aSelector {
    // See http://stackoverflow.com/questions/14602854/objective-c-is-there-a-way-to-check-a-selector-return-value
    Method m = class_getInstanceMethod([self class], aSelector);
    char type[128];
    method_getReturnType(m, type, sizeof(type));

    NSString *message = [[NSString alloc] initWithFormat:@"NSObject+Extras.performVoidReturnSelector: %@.%@ selector (type[0] (hex): %x)", [self class], NSStringFromSelector(aSelector), type[0]];
    //SPASLogDetail(@"%@", message);
    
    switch (type[0]) {
        // void return type in Objective-C
        case 'v':
            break;
            
        default:
            AssertIf(YES, @"%@ was not void", message);
            SPASLogFile(@"%@ was not void", message);
            break;
    }
}

- (void) performVoidReturnSelector:(SEL)aSelector withObject:(id)object {
    [self checkSelector:aSelector];

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
    // Since the selector (aSelector) is returning void, it doesn't make sense to try to obtain the return result of performSelector. In fact, if we do, it crashes the app.
    [self performSelector: aSelector withObject: object];
#pragma clang diagnostic pop    
}

- (void) performVoidReturnSelector:(SEL)aSelector {
    [self checkSelector:aSelector];
    
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
    SPASLogDetail(@"self: %@; selector: %@", self, NSStringFromSelector(aSelector));
    [self performSelector: aSelector];
#pragma clang diagnostic pop
}

// See http://stackoverflow.com/questions/9219030/dealloc-not-being-called-on-arc-app
- (NSInteger) arcReferenceCount;
{
    CFIndex rc = CFGetRetainCount((__bridge CFTypeRef)self);
    return rc;
}

#pragma mark - Support for debouncing

static char kDebounceKey;

- (void) setupBlockDebounceWithInterval: (NSTimeInterval) intervalInSeconds;
{
    Debounce *debounce = [[Debounce alloc] initWithType:DebounceTypeDelay];
    if (intervalInSeconds > 0) {
        debounce.interval = intervalInSeconds;
    }
    objc_setAssociatedObject(self, &kDebounceKey, debounce, OBJC_ASSOCIATION_RETAIN);
}

- (void) setBlockToDebounce: (void (^)(void)) blockToDebounce;
{
    Debounce *debounce = (Debounce *) objc_getAssociatedObject(self, &kDebounceKey);
    [debounce queueBlock:blockToDebounce];
}

#pragma mark -

@end
