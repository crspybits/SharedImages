//
//  MutableBOOL.h
//  Petunia
//
//  Created by Christopher Prince on 8/19/14.
//  Copyright (c) 2014 Spastic Muffin, LLC. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface MutableBOOL : NSObject

- (instancetype) initWithValue: (BOOL) initialValue;

@property (nonatomic) BOOL value;

@end
