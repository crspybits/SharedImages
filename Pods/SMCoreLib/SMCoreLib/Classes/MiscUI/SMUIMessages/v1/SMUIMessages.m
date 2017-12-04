//
//  SMUIMessages.m
//  Catsy
//
//  Created by Christopher Prince on 6/13/15.
//  Copyright (c) 2015 Spastic Muffin, LLC. All rights reserved.
//

#define OK_MSG @"OK"
#define LEFT_NAV_CLOSE_BUTTON_TITLE @"Close"

#import "SMUIMessages.h"

@implementation SMUIMessages

+ (instancetype) session;
{
    static SMUIMessages *session = nil;
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        session = [[self alloc] init];
    });
    
    return session;
}

- (NSString *) OkMsg;
{
    return OK_MSG;
}

- (NSString *) leftNavCloseButtonTitle;
{
    return LEFT_NAV_CLOSE_BUTTON_TITLE;
}

@end
