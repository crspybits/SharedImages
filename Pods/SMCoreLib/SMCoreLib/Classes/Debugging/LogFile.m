//
//  LogFile.m
//  WhatDidILike
//
//  Created by Christopher Prince on 1/24/13.
//
//

#import "LogFile.h"
#import "FileStorage.h"
#import "UIDevice+Extras.h"

@implementation LogFile

+ (LogFile *)sharedInstance
{
    // the instance of this class is stored here
    static LogFile *myInstance = nil;
    
    // check to see if an instance already exists
    if (nil == myInstance) {
        myInstance  = [[[self class] alloc] init];
        
        NSString *logFileName = [FileStorage pathToItem: LOGFILE];
        
        /*NSOutputStream *oStream = [[NSOutputStream alloc] initToFileAtPath:logFileName append:YES];
        [oStream open];
        */
        
        // the writeData method of NSFileHandle doesn't create the file
        // it doesn't already exist, so have to do something a little convoluted
        
        myInstance->fileHandle = [NSFileHandle fileHandleForWritingAtPath:logFileName];
        if (nil == myInstance->fileHandle) {
            // file didn't exist yet; so create it.
            [[NSFileManager defaultManager] createFileAtPath:logFileName contents:nil attributes:nil];
            
            // Now open it!
            myInstance->fileHandle = [NSFileHandle fileHandleForWritingAtPath:logFileName];
        }
        
        // By default, the file pointer is initially positioned at the start 
        // of the file.
        [myInstance->fileHandle seekToEndOfFile];

        // This does not append to the file.
        //[dataToWrite writeToFile:logFileName atomically:NO encoding:NSUTF8StringEncoding error:nil];

        //[LogFile LocalInit:myInstance];
    }
    
    // return the instance of this class
    return myInstance;
}

// TODO: Don't want the log file to grow too too large. So, if the log file
// gets too large, delete the first 1/2 of the lines of the file
// before writing next log message.

/*
+ (void) write:(id) firstObject, ...
{
    LogFile *lf = [LogFile sharedInstance];
    NSDate *date = [[NSDate alloc] init];
    
    // Writes objects that have descriptions.
    void (^writeObject)(id) = ^(id objectToWrite) {
        [lf->fileHandle writeData:[[objectToWrite description]dataUsingEncoding:NSUTF8StringEncoding]];
        [lf->fileHandle writeData:[@"; " dataUsingEncoding:NSUTF8StringEncoding]];
    };
    
    writeObject(date);
    
    id nextObject;
    va_list argumentList;
    
    if (firstObject)                    // The first argument isn't part of the varargs list,
    {                                   // so we'll handle it separately.
        writeObject(firstObject);
        if (LogFileDebug) NSLog(@"%@", firstObject);
        
        va_start(argumentList, firstObject);  // Start scanning for arguments after firstObject.
        for (;;) {
            nextObject = va_arg(argumentList, id);
            if (! nextObject) break;
            
            writeObject(nextObject);
            if (LogFileDebug) NSLog(@"%@", nextObject);
        }
        va_end(argumentList);
    }
    
    [lf->fileHandle synchronizeFile];

}
*/

+ (void) write : (NSString *) dataString {
    LogFile *lf = [LogFile sharedInstance];
    
    // 9/12/15; Adding date in higher level code that creates the message.
    // NSDate *date = [[NSDate alloc] init];
    
    // Writes objects that have descriptions.
    void (^writeObject)(id) = ^(id objectToWrite) {
        [lf->fileHandle writeData:[[objectToWrite description]dataUsingEncoding:NSUTF8StringEncoding]];
        
        // 9/12/15; Not needed any more.
        //[lf->fileHandle writeData:[@"; " dataUsingEncoding:NSUTF8StringEncoding]];
    };
    
    // writeObject(date);
    writeObject(dataString);

    [lf->fileHandle synchronizeFile];
}

// Requires plist setting:  UIFileSharingEnabled set to YES

// direct the console log to documents folder.

// From BBT
+ (void) redirectConsoleLogToDocumentFolder:(bool) clearRedirectLog;
{
    if ([UIDevice beingDebugged]) {
        return;
    }
    
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);

    NSString *documentsDirectory = [paths objectAtIndex:0];

    NSString *logPath = [documentsDirectory stringByAppendingPathComponent:@"console.log"];

    if (clearRedirectLog) {

        // For error information
        NSError *error;
        
        // Create file manager
        NSFileManager *fileMgr = [NSFileManager defaultManager];

        if ([fileMgr removeItemAtPath:logPath error:&error] != YES)

            NSLog(@"Unable to delete file: %@", [error localizedDescription]);

    }

    freopen([logPath cStringUsingEncoding:NSASCIIStringEncoding],"a+",stderr);
}

+ (void) clearR
{
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);

    NSString *documentsDirectory = [paths objectAtIndex:0];

    NSString *logPath = [documentsDirectory stringByAppendingPathComponent:@"console.log"];

    // For error information
    NSError *error;

    // Create file manager
    NSFileManager *fileMgr = [NSFileManager defaultManager];

    [fileMgr removeItemAtPath:logPath error:&error];
}

@end
