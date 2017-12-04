//
//  NSURL+Extras.h
//  Petunia
//
//  Created by Christopher Prince on 3/27/15.
//  Copyright (c) 2015 Spastic Muffin, LLC. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSURL (Extras)

// Given that the query property of the NSURL is: x1=y1&x2=y2 etc. returns a dictionary where the x's are the keys and the y's are the values of those keys.
- (NSDictionary *) queryItems;

@end
