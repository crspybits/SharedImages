//
//  CLPlacemark+Extras.h
//  WhatDidILike
//
//  Created by Christopher Prince on 8/23/15.
//  Copyright (c) 2015 Spastic Muffin, LLC. All rights reserved.
//

// Convenience methods to access the addressDictionary property.

#import <CoreLocation/CoreLocation.h>

@interface CLPlacemark (Extras)

@property (nonatomic, strong, readonly) NSString *addressDictionaryCity;

// Two letter state code for USA.
@property (nonatomic, strong, readonly) NSString *addressDictionaryState;

@end
