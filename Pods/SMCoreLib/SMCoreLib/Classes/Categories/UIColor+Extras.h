//
//  UIColor+Extras.h
//  Petunia
//
//  Created by Christopher Prince on 8/9/14.
//  Copyright (c) 2014 Spastic Muffin, LLC. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface UIColor (Extras)

- (UIColor *)lighterColor;
- (UIColor *)darkerColor;

// Works across iOS versions.
- (BOOL) getComponentsRed: (CGFloat *) red green:(CGFloat *) green blue: (CGFloat *) blue;

// E.g., if this is in a grayscale color space. Alpha of the returned color is 1.
- (UIColor *) convertToRGBColorSpace;

// Assumes input like @"#00FF00" (#RRGGBB).
+ (UIColor *)colorFromHexString:(NSString *)hexString;

@end
