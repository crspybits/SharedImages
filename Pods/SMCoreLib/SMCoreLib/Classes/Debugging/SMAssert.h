//
//  SMAssert.h
//  Petunia
//
//  Created by Christopher Prince on 7/26/14.
//  Copyright (c) 2014 Spastic Muffin, LLC. All rights reserved.
//

#import "SPASLog.h"

#ifdef DEBUG
    #define AssertIf(ConditionIsTrue, ThenPrintThisStringFmt, ...)\
        {\
            if (ConditionIsTrue) SPASLogDetail(ThenPrintThisStringFmt, ##__VA_ARGS__);\
            NSAssert(!(ConditionIsTrue), @"Assertion Failure");\
        }
#else
    #define AssertIf(ConditionIsTrue, ThenPrintThisStringFmt, ...)\
        if (ConditionIsTrue) SPASLogFile(ThenPrintThisStringFmt, ##__VA_ARGS__);
#endif

// Do the assert in development; do an action in production.
// The string to print can't have arguments or formatting.
#ifdef DEBUG
    #define AssertActionIf(ConditionIsTrue, DevelopmentPrintThisString, ProductionCodeAction...)\
        {\
            if (ConditionIsTrue) SPASLogDetail(DevelopmentPrintThisString);\
            NSAssert(!(ConditionIsTrue), @"Assertion Failure");\
        }
#else
    #define AssertActionIf(ConditionIsTrue, DevelopmentPrintThisString, ProductionCodeAction...)\
        if (ConditionIsTrue) {\
            SPASLogFile(DevelopmentPrintThisString);\
            ProductionCodeAction;\
        }
#endif

// This is useful within blocks. Using NSAssert within blocks causes a warning.
#ifdef DEBUG
    #define WeakAssertIf(ConditionIsTrue, ThenPrintThisString)\
        if (ConditionIsTrue) {\
            SPASLog(@"%@", ThenPrintThisString);\
            abort();\
        }
#else
    #define WeakAssertIf(ConditionIsTrue, ThenPrintThisString)\
        if (ConditionIsTrue) {\
            SPASLogFile(@"%@", ThenPrintThisString);\
        }
#endif

// Always throw the assert
#define BadMojo(ThenPrintThisString)\
    AssertIf(YES, ThenPrintThisString)

#define WeakBadMojo(ThenPrintThisString)\
    WeakAssertIf(YES, ThenPrintThisString)

#import <Foundation/Foundation.h>

@interface SMAssert : NSObject

@end
