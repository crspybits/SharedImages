//
//  WeakRef.h
//  Petunia
//
//  Created by Christopher Prince on 9/1/14.
//  Copyright (c) 2014 Spastic Muffin, LLC. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface WeakRef : NSObject

+ (instancetype) toObj: (id) obj;
+ (id) from: (WeakRef *) weakRef;

@property (nonatomic, weak) id obj;

@end
