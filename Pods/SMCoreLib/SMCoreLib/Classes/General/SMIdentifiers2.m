//
//  SMIdentifiers2.m
//  SMCommon
//
//  Created by Christopher Prince on 10/3/15.
//  Copyright © 2015 Spastic Muffin, LLC. All rights reserved.
//

#import "SMIdentifiers2.h"

@implementation SMIdentifiers2

+ (instancetype) session;
{
    static SMIdentifiers2* s_sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        s_sharedInstance = [self new];
    });
    
    return s_sharedInstance;
}

- (NSString *) bundleIdentifier;
{
    // 10/3/15. This is redundant with SMIdentifiers.appBundleIdentifier, but I had a whole lot of difficultly (see [1] above), trying to use SMIdentifiers.swift from within the KeyChain. I'm compromising by putting this in a separate Obj-C class.
    return [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleIdentifier"];
}

@end
