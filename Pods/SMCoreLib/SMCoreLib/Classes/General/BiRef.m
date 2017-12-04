//
//  BiRef.m
//  Petunia
//
//  Created by Christopher Prince on 9/3/14.
//  Copyright (c) 2014 Spastic Muffin, LLC. All rights reserved.
//

#import "BiRef.h"

@interface BiRef()
@end

@implementation BiRef

- (instancetype) init;
{
    self = [super init];
    if (self) {
        self.strongRef = YES;
    }
    return self;
}

+ (instancetype) weakRefToObj: (id) obj;
{
    BiRef *biRefObj = [BiRef new];
    biRefObj.wObj = obj;
    return biRefObj;
}

+ (instancetype) strongRefToObj: (id) obj;
{
    BiRef *biRefObj = [BiRef new];
    biRefObj.sObj = obj;
    return biRefObj;
}

+ (id) currentFrom: (BiRef *) ref;
{
    if (ref.strongRef) {
        return ref.sObj;
    }
    
    return ref.wObj;
}

- (id) obj;
{
    return [BiRef currentFrom:self];
}

- (void) setStrongRef:(BOOL)strongRef
{
    if (strongRef != _strongRef) {
        if (strongRef) {
            // Make a strong reference.
            _sObj = self.wObj;
            _wObj = nil;
        } else {
            // Make weak a reference. Of course, this may cause the object to "go away" because we had the only strong reference.
            _wObj = self.sObj;
            _sObj = nil;
        }
        
        _strongRef = strongRef;
    }
}

- (void) setSObj:(id)sObj;
{
    self.strongRef = YES;
    _sObj = sObj;
}

- (void) setWObj:(id)wObj;
{
    self.strongRef = NO;
    _wObj = wObj;
}

@end
