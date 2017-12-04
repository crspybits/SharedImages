//
//  RosterDevInjectTestObjC.m
//  roster
//
//  Created by Christopher G Prince on 8/9/17.
//  Copyright © 2017 roster. All rights reserved.
//

#import "RosterDevInjectTestObjC.h"

@interface RosterDevInjectTestObjC()
@property (nonatomic, strong) NSMutableDictionary *values;
@end

@implementation RosterDevInjectTestObjC

#define USER_DEFS_KEY @"RosterDevInjectTestObjc"

+ (instancetype) session;
{
    static RosterDevInjectTestObjC *session = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        session = [self new];
        session.values = [NSMutableDictionary new];
        [session loadFromDefs];
    });
    
    return session;
}

- (void) saveToDefs;
{
    NSData *data = [NSKeyedArchiver archivedDataWithRootObject:self.values];
    [[NSUserDefaults standardUserDefaults] setObject:data forKey:USER_DEFS_KEY];
    [[NSUserDefaults standardUserDefaults]  synchronize];
}

- (void) loadFromDefs;
{
    NSData *defs = [[NSUserDefaults standardUserDefaults] dataForKey:USER_DEFS_KEY];
    if (defs) {
        NSDictionary *dict = [NSKeyedUnarchiver unarchiveObjectWithData: defs];
        [self.values addEntriesFromDictionary:dict];
    }
}

- (void) reset;
{
    [self.values removeAllObjects];
    [self saveToDefs];
}

- (NSArray <NSString *>*) sortedTestCaseNames;
{
    return [self.values.allKeys sortedArrayWithOptions:0
               usingComparator:^NSComparisonResult(id obj1, id obj2) {
        NSString *name1 = obj1;
        NSString *name2 = obj2;
        return [name1 compare:name2 options:NSCaseInsensitiveSearch];
    }];
}

- (BOOL) testIsOn: (NSString *) testCaseName;
{    
    NSNumber *testCaseValue = self.values[testCaseName];
    if (testCaseValue == nil) {
        return NO;
    }
    else {
        return [testCaseValue boolValue];
    }
}

- (void) setTest: (NSString *) testCaseName valueTo: (BOOL) testCaseValue;
{
    self.values[testCaseName] = [NSNumber numberWithBool:testCaseValue];
    [self saveToDefs];
}

- (void) defineTest: (NSString *) testCaseName;
{
    if (!self.values[testCaseName]) {
        [self setTest:testCaseName valueTo:NO];
    }
}

- (void) swiftRun: (NSString *) testCaseName ifOn: (void (^)(void)) callback;
{    
#ifdef DEBUG
    RosterDevInjectTestIf(testCaseName, {
        if (callback) {
            callback();
        }
    });
#endif
}

@end
