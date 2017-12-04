//
//  CallCounter.m
//  Petunia
//
//  Created by Christopher Prince on 10/8/14.
//  Copyright (c) 2014 Spastic Muffin, LLC. All rights reserved.
//

#import "CallCounter.h"
#import "SPASLog.h"
#import "NSObject+Extras.h"

@interface CallCounter()<NSCoding>
@property (nonatomic) NSUInteger countOfTimesCalled;
@property (nonatomic) NSUInteger numberOfTimes;
@property (nonatomic) NSString *selectorAsString;
@property (nonatomic, strong) NSObject<NSCoding> *dataObject;
@end

@implementation CallCounter

- (instancetype) initWithCoder:(NSCoder *)aDecoder;
{
    self = [super init];
    if (self) {
        self.countOfTimesCalled = [aDecoder decodeIntForKey:@"countOfTimesCalled"];
        self.numberOfTimes = [aDecoder decodeIntForKey:@"numberOfTimes"];
        self.selectorAsString = [aDecoder decodeObjectForKey:@"selectorAsString"];
        self.dataObject = [aDecoder decodeObjectForKey:@"dataObject"];
    }
    return self;
}

- (void) encodeWithCoder:(NSCoder *)aCoder;
{
    [aCoder encodeInteger:self.countOfTimesCalled forKey:@"countOfTimesCalled"];
    [aCoder encodeInteger:self.numberOfTimes forKey:@"numberOfTimes"];
    [aCoder encodeObject:self.selectorAsString forKey:@"selectorAsString"];
    [aCoder encodeObject:self.dataObject forKey:@"dataObject"];
}

+ (void) withKey: (NSString *) nsUserDefaultsKey numberOfTimes: (NSUInteger) numberOfTimes target: (SEL) selector andObject: (NSObject<NSCoding> *)dataObject;
{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSData *callTimerData = [defaults objectForKey:nsUserDefaultsKey];
    
    if (callTimerData) {
        CallCounter *callTimer = [NSKeyedUnarchiver unarchiveObjectWithData:callTimerData];
        [callTimer doCallWithKey:nsUserDefaultsKey];
    } else {
        CallCounter *callTimer = [CallCounter new];
        callTimer.numberOfTimes = numberOfTimes;
        callTimer.selectorAsString = NSStringFromSelector(selector);
        callTimer.dataObject = dataObject;
        NSData *callTimerData = [NSKeyedArchiver archivedDataWithRootObject:callTimer];
        [defaults setObject:callTimerData forKey:nsUserDefaultsKey];
        [defaults synchronize];
    }
}

- (void) doCallWithKey: (NSString *) nsUserDefaultsKey;
{
    self.countOfTimesCalled++;
    SPASLog(@"self.countOfTimesCalled: %lu, self.numberOfTimes: %lu", (unsigned long)self.countOfTimesCalled, (unsigned long)self.numberOfTimes);
    
    if (self.countOfTimesCalled > self.numberOfTimes) {
        return;
    }
    
    // Either we are about to call the method, and we want to make sure we don't call it again. Or we haven't yet reached the count, and will call it in the future. Either way, save the countOfTimesCalled, for next time this is called.
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSData *callTimerData = [NSKeyedArchiver archivedDataWithRootObject:self];
    [defaults setObject:callTimerData forKey:nsUserDefaultsKey];
    [defaults synchronize];
    
    if (self.countOfTimesCalled == self.numberOfTimes) {
        // Do the call.
        SEL selector = NSSelectorFromString(self.selectorAsString);
        [self.dataObject performVoidReturnSelector:selector];
    }
}

+ (void) callWithKey: (NSString *) nsUserDefaultsKey;
{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSData *callTimerData = [defaults objectForKey:nsUserDefaultsKey];
    if (callTimerData) {
        CallCounter *callTimer = [NSKeyedUnarchiver unarchiveObjectWithData:callTimerData];
        [callTimer doCallWithKey:nsUserDefaultsKey];
    }
}

+ (void) resetKey: (NSString *) nsUserDefaultsKey;
{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults removeObjectForKey:nsUserDefaultsKey];
}

@end
