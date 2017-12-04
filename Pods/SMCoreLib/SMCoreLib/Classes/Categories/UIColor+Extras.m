//
//  UIColor+Extras.m
//  Petunia
//
//  Created by Christopher Prince on 8/9/14.
//  Copyright (c) 2014 Spastic Muffin, LLC. All rights reserved.
//

#import "UIColor+Extras.h"

@implementation UIColor (Extras)

// Adapted from: http://stackoverflow.com/questions/11598043/get-slightly-lighter-and-darker-color-from-uicolor

- (UIColor *)lighterColorRemoveSaturation:(CGFloat)removeS
                              resultAlpha:(CGFloat)alpha {
    CGFloat h,s,b,a;
    if ([self getHue:&h saturation:&s brightness:&b alpha:&a]) {
        return [UIColor colorWithHue:h
                          saturation:MAX(s - removeS, 0.0)
                          brightness:b
                               alpha:alpha == -1? a:alpha];
    }
    return nil;
}

- (UIColor *)darkerColorAddSaturation:(CGFloat)addS
                              resultAlpha:(CGFloat)alpha {
    CGFloat h,s,b,a;
    if ([self getHue:&h saturation:&s brightness:&b alpha:&a]) {
        return [UIColor colorWithHue:h
                          saturation:MIN(s + addS, 1.0)
                          brightness:b
                               alpha:alpha == -1? a:alpha];
    }
    return nil;
}

#define CHANGE_AMOUNT 0.5

- (UIColor *)lighterColor;
{
    return [self lighterColorRemoveSaturation:CHANGE_AMOUNT
                                  resultAlpha:-1];
}

- (UIColor *)darkerColor;
{
    return [self darkerColorAddSaturation:CHANGE_AMOUNT
                                  resultAlpha:-1];
}

// See http://stackoverflow.com/questions/4700168/get-rgb-value-from-uicolor-presets
- (void)getRGBComponents:(CGFloat [3])components forColor:(UIColor *)color {
    CGColorSpaceRef rgbColorSpace = CGColorSpaceCreateDeviceRGB();
    unsigned char resultingPixel[4];
    CGContextRef context = CGBitmapContextCreate(&resultingPixel,
                                                 1,
                                                 1,
                                                 8,
                                                 4,
                                                 rgbColorSpace,
                                                 (CGBitmapInfo) kCGImageAlphaNoneSkipLast);
    CGContextSetFillColorWithColor(context, [color CGColor]);
    CGContextFillRect(context, CGRectMake(0, 0, 1, 1));
    CGContextRelease(context);
    CGColorSpaceRelease(rgbColorSpace);
    
    for (int component = 0; component < 3; component++) {
        components[component] = resultingPixel[component] / 255.0f;
    }
}

- (BOOL) getComponentsRed: (CGFloat *) red green:(CGFloat *) green blue: (CGFloat *) blue;
{
    // Until iOS7, getRed:green:blue: doesn't work in all color spaces.
    CGFloat alpha;
    BOOL result = [self getRed:red green:green blue:blue alpha:&alpha];
    if (result) {
        return result;
    }

    // E.g., See http://stackoverflow.com/questions/4700168/get-rgb-value-from-uicolor-presets
    CGFloat components[3];
    [self getRGBComponents:components forColor:self];
    *red = components[0];
    *green = components[1];
    *blue = components[2];
    
    return YES;
}

- (UIColor *) convertToRGBColorSpace;
{
    CGFloat red=0.0, green=0.0, blue= 0.0;
    if ([self getComponentsRed:&red green:&green blue:&blue]) {
        return [UIColor colorWithRed:red green:green blue:blue alpha:1.0];
    }
    
    return nil;
}

// See http://stackoverflow.com/questions/1560081/how-can-i-create-a-uicolor-from-a-hex-string
+ (UIColor *)colorFromHexString:(NSString *)hexString;
{
    unsigned rgbValue = 0;
    NSScanner *scanner = [NSScanner scannerWithString:hexString];
    [scanner setScanLocation:1]; // bypass '#' character
    [scanner scanHexInt:&rgbValue];
    return [UIColor colorWithRed:((rgbValue & 0xFF0000) >> 16)/255.0 green:((rgbValue & 0xFF00) >> 8)/255.0 blue:(rgbValue & 0xFF)/255.0 alpha:1.0];
}

@end
