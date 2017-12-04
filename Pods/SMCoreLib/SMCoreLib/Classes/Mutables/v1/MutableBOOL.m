//
//  MutableBOOL.m
//  Petunia
//
//  Created by Christopher Prince on 8/19/14.
//  Copyright (c) 2014 Spastic Muffin, LLC. All rights reserved.
//

#import "MutableBOOL.h"

@implementation MutableBOOL

- (instancetype) initWithValue: (BOOL) initialValue;
{
    self = [super init];
    if (self) {
        self.value = initialValue;
    }
    
    return self;
}

@end
