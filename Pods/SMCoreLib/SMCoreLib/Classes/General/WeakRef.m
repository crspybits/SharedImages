//
//  WeakRef.m
//  Petunia
//
//  Created by Christopher Prince on 9/1/14.
//  Copyright (c) 2014 Spastic Muffin, LLC. All rights reserved.
//

#import "WeakRef.h"

@implementation WeakRef

+ (instancetype) toObj: (id) obj;
{
    WeakRef *result = [WeakRef new];
    result.obj = obj;
    return result;
}

+ (id) from: (WeakRef *) weakRef;
{
    return weakRef.obj;
}

@end
