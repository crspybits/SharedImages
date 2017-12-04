//
//  BiRef.h
//  Petunia
//
//  Created by Christopher Prince on 9/3/14.
//  Copyright (c) 2014 Spastic Muffin, LLC. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface BiRef : NSObject

+ (instancetype) weakRefToObj: (id) obj;
+ (instancetype) strongRefToObj: (id) obj;

// Returns a strong or weak reference depending on strongRef.
+ (id) currentFrom: (BiRef *) ref;

// Same as currentFrom:, but an instance method. (Note that this can't be a property because we'll have to indicate if it's strong or weak).
- (id) obj;

// The default is YES, a strong reference.
@property (nonatomic) BOOL strongRef;

// Only one of these can ever be non-nil. If strongRef is NO, then wObj is the relevant reference. If strongRef is YES, then sObj is the relevant reference.
@property (nonatomic, weak) id wObj;
@property (nonatomic, strong) id sObj;

@end
