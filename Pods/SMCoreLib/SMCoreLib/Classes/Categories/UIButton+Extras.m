//
//  UIButton+Extras.m
//  Catsy
//
//  Created by Christopher Prince on 7/7/15.
//  Copyright (c) 2015 Spastic Muffin, LLC. All rights reserved.
//

#import "UIButton+Extras.h"

@implementation UIButton (Extras)

// See http://stackoverflow.com/questions/14523348/how-to-change-the-background-color-of-a-uibutton-while-its-highlighted
+ (UIImage *)createBackgroundImageWithColor:(UIColor *)color;
{
    CGRect rect = CGRectMake(0.0f, 0.0f, 1.0f, 1.0f);
    UIGraphicsBeginImageContext(rect.size);
    CGContextRef context = UIGraphicsGetCurrentContext();
    
    CGContextSetFillColorWithColor(context, [color CGColor]);
    CGContextFillRect(context, rect);
    
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    return image;
}

@end
