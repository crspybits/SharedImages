//
//  UUID.m
//
//  Created by Christopher Prince on 10/28/14.
//  Copyright (c) 2014 Spastic Muffin, LLC. All rights reserved.
//

#import "UUID.h"

@implementation UUID

// http://stackoverflow.com/questions/10476313/how-do-i-create-a-cfuuid-nsstring-under-arc-that-doesnt-leak/22839680#22839680
+ (NSString *) make;
{
    CFUUIDRef theUUID = CFUUIDCreate(NULL);
    CFStringRef string = CFUUIDCreateString(NULL, theUUID);
    CFRelease(theUUID);
    return (__bridge_transfer NSString *)string;
}

@end
