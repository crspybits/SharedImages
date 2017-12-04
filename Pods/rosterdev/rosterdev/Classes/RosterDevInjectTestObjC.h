//
//  RosterDevInjectTestObjC.h
//  roster
//
//  Created by Christopher G Prince on 8/9/17.
//  Copyright © 2017 roster. All rights reserved.
//

// Persistent test case values and test injection. I'm persisting these across app launches so that you can set a test case value, and use that in the next launch of the app-- i.e., for a test that occurs during the launch of the app.

// I'm doing part of this in Objective-C because this gives me more expressive macros, and I need those macros to conditionally compile out this test injection in production deployed apps.

#import <Foundation/Foundation.h>

#ifdef DEBUG
#define RosterDevInjectTestIf(testCaseName, testCode)\
    if ([[RosterDevInjectTestObjC session] testIsOn:testCaseName]) {\
        if (![RosterDevInjectTestObjC session].runTestsMultipleTimes) {\
            [[RosterDevInjectTestObjC session] setTest:testCaseName valueTo:NO];\
        }\
        testCode;\
    }
#else
#define RosterDevInjectTestIf(TestName, TestCode)
#endif

@interface RosterDevInjectTestObjC : NSObject

+ (instancetype) session;

// Defaults to NO.
@property (nonatomic) BOOL runTestsMultipleTimes;

@property (nonatomic, strong) NSArray <NSString *>*sortedTestCaseNames;

// Clears all definitions. All test cases will now be NO when called with testIsOn:
- (void) reset;

- (BOOL) testIsOn: (NSString *) testCaseName;

// If the value of the test case is not set, sets it to NO. If it is set, doesn't do anything.
- (void) defineTest: (NSString *) testCaseName;

- (void) setTest: (NSString *) testCaseName valueTo: (BOOL) testCaseValue;

// For use from Swift; the body of this conditionally compiles out in production so the callback will *never* be called then. This is the best we can do. Perhaps the compiler will notice that the method does nothing and optimize it out completely?
- (void) swiftRun: (NSString *) testCaseName ifOn: (void (^)(void)) callback;

@end
