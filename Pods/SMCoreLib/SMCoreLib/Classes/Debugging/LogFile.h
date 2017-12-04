//
//  LogFile.h
//  WhatDidILike
//
//  Created by Christopher Prince on 1/24/13.
//  Methods to store messages to a log file, for error logging.
//

#import <Foundation/Foundation.h>

#ifndef LOGFILE
#define LOGFILE @"LogFile.txt"
#endif

@interface LogFile : NSObject {
    NSFileHandle *fileHandle; // for open log file.
}

/*

 */

// See http://gcc.gnu.org/onlinedocs/cpp/Variadic-Macros.html
// And see http://gcc.gnu.org/onlinedocs/cpp/Pragmas.html
// 8/29/14; CGP; Deprecated
#define LogError(...)\
    {\
    _Pragma ("clang diagnostic push")\
    _Pragma ("clang diagnostic ignored \"-Wformat-nonliteral\"")\
    NSLog(__VA_ARGS__);\
    [LogFile write: [NSString stringWithFormat:__VA_ARGS__]];\
    _Pragma ("clang diagnostic pop")\
    }

// Appends the string to the logfile. Prepends current date to the log message.
+ (void) write:(NSString *) message;

+ (void) redirectConsoleLogToDocumentFolder:(bool) clearRedirectLog;

@end
