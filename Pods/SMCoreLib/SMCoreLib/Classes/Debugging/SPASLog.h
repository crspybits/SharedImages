//
//  KGDebugging.pch
//  KGFramework
//
//  Created by Kendall Gelner on 1/24/10.
//  Copyright 2010 KiGi Software. All rights reserved.
//
//  Permission is hereby granted, free of charge, to any person
//  obtaining a copy of this software and associated documentation
//  files (the "Software"), to deal in the Software without
//  restriction, including without limitation the rights to use,
//  copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the
//  Software is furnished to do so, subject to the following
//  conditions:
//
//  The above copyright notice and this permission notice shall be
//  included in all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
//  EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
//  OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
//  NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
//  HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
//  WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
//  FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
//  OTHER DEALINGS IN THE SOFTWARE.
//

#ifdef __OBJC__

#import "LogFile.h"

#ifdef DEBUG
// Bog standard Logging
    #define SPASLog(fmt, ...) NSLog(fmt, ##__VA_ARGS__);
// Log statement with a bit more detail as to where you are
    #define SPASLogDetail(fmt, ...) NSLog((@"%s [Line %d] " fmt), __PRETTY_FUNCTION__, __LINE__, ##__VA_ARGS__);
// Log statement without the normal NSLog fluff at the start 
    #define SPASLogNoFluff(fmt, ...) fprintf( stderr, "%s\n", [[NSString stringWithFormat:(@"%s [Line %d] " fmt), __PRETTY_FUNCTION__, __LINE__, ##__VA_ARGS__] UTF8String] );
// Logs out to a UILocalNotification, where you can pull it down in Notification Center
    #define SPASLogLocalNotification(fmt, ...) UILocalNotification *localNotif__LINE__ = [[UILocalNotification alloc] init];\
    if (localNotif__LINE__) {\
        localNotif__LINE__.alertBody = [NSString stringWithFormat:(fmt), ##__VA_ARGS__];\
        [[UIApplication sharedApplication] presentLocalNotificationNow:localNotif__LINE__];\
    }

#else
// No definition unless debugging is on
    #define SPASLog(fmt, ...)
    #define SPASLogDetail(fmt, ...)
    #define SPASLogNoFluff(fmt, ...)
    #define SPASLogLocalNotification(fmt, ...)

    // I'm always going to write the message to the log file, so users can send me a log file.
    //#define SPASLogFile(fmt, ...)
#endif

// Log to a file.
// 9/12/15; Just added a date into this as I took the date out of the LogFile write method.
#define SPASLogFile(fmt, ...)\
    {\
        SPASLogDetail(fmt, ##__VA_ARGS__);\
        [LogFile write: [NSString stringWithFormat:(@"%@; %s [Line %d] " fmt), [NSDate date], __PRETTY_FUNCTION__, __LINE__, ##__VA_ARGS__]];\
        [LogFile write: @"\n"];\
    }

#endif
