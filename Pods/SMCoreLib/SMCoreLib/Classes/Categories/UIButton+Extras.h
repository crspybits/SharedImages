//
//  UIButton+Extras.h
//  Catsy
//
//  Created by Christopher Prince on 7/7/15.
//  Copyright (c) 2015 Spastic Muffin, LLC. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface UIButton (Extras)

// Intended for making a UIButton have a solid background color. After creating the image with this color, set it using:
// [button setBackgroundImage:backgroundImage forState:UIControlStateNormal];
+ (UIImage *)createBackgroundImageWithColor:(UIColor *)color;

@end
