//
//  LazyFrame.h
//  Petunia
//
//  Created by Christopher Prince on 5/29/13.
//  Copyright (c) 2013 Christopher Prince. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

// The purpose of this class is to provide lazy evaluation to obtain a frame
@interface LazyFrame : NSObject
@property (nonatomic) CGRect frame;
@end
