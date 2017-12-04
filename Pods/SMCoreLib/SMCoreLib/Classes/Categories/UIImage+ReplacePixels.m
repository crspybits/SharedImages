//
//  UIImage+ReplacePixels.m
//  Petunia
//
//  Created by Christopher Prince on 11/13/14.
//  Copyright (c) 2014 Spastic Muffin, LLC. All rights reserved.
//

#import "UIImage+ReplacePixels.h"
#import "UIColor+Extras.h"

@implementation UIImage (ReplacePixels)

typedef unsigned char byte;

// CGP modified this code from: https://gist.github.com/chrishulbert/1034150#file-colourise-m

- (UIImage *) replaceVisiblePixelsWith: (UIColor *) color;
{
    int colR, colG, colB;
    
    CGFloat red=0.0, green=0.0, blue=0.0;
    [color getComponentsRed:&red green:&green blue:&blue];
    
    colR = (int) (red*255.0);
    colG = (int) (green*255.0);
    colB = (int) (blue*255.0);
    
    // Thanks (by github author): http://brandontreb.com/image-manipulation-retrieving-and-updating-pixel-values-for-a-uiimage/
    CGContextRef ctx;
    CGImageRef imageRef = [self CGImage];
    NSUInteger width = CGImageGetWidth(imageRef);
    NSUInteger height = CGImageGetHeight(imageRef);
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    byte *rawData = malloc(height * width * 4);
    if (!rawData) {
        return nil;
    }
    
    NSUInteger bytesPerPixel = 4;
    NSUInteger bytesPerRow = bytesPerPixel * width;
    NSUInteger bitsPerComponent = 8;
    
    // I don't know why this should be necessary, but on iOS7 it is. On iOS8 all is fine. On iOS7 does CGBitmapContextCreate not initialize all elements?
    for (int byteNum = 0 ; byteNum < width * height * bytesPerPixel; byteNum++) {
        rawData[byteNum] = 0;
    }

    CGContextRef context = CGBitmapContextCreate(rawData, width, height,
                                                 bitsPerComponent, bytesPerRow, colorSpace,
                                                 kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big);
    
    CGContextDrawImage(context, CGRectMake(0, 0, width, height), imageRef);
    CGContextRelease(context);
    
    NSUInteger byteIndex = 0;
    while (byteIndex < width * height * bytesPerPixel) {
        int alpha = rawData[byteIndex+3];

        //SPASLog(@"alpha= %f", alpha);
        
        if (alpha > 0) {
            rawData[byteIndex] = colR; // MAX(0,MIN(255,(int)(colR*alphaMultiplier)));
            rawData[byteIndex+1] = colG; // MAX(0,MIN(255,(int)(colG*alphaMultiplier)));
            rawData[byteIndex+2] = colB; // MAX(0,MIN(255,(int)(colB*alphaMultiplier)));
            rawData[byteIndex+3] = 255;
        }

        byteIndex += 4;
    }
    
    ctx = CGBitmapContextCreate(rawData,
                                CGImageGetWidth( imageRef ),
                                CGImageGetHeight( imageRef ),
                                8,
                                bytesPerRow,
                                colorSpace,
                                (CGBitmapInfo) kCGImageAlphaPremultipliedLast);
    // For the above coercion, see http://stackoverflow.com/questions/18921703/implicit-conversion-from-enumeration-type-enum-cgimagealphainfo-to-different-e
    
    CGColorSpaceRelease(colorSpace);
    
    imageRef = CGBitmapContextCreateImage (ctx);
    UIImage* rawImage = [UIImage imageWithCGImage:imageRef];  
    CGImageRelease(imageRef);
    
    CGContextRelease(ctx);  
    free(rawData);
    
    return rawImage;
}

@end
