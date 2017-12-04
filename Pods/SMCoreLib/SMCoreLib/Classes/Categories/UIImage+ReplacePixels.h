//
//  UIImage+ReplacePixels.h
//  Petunia
//
//  Created by Christopher Prince on 11/13/14.
//  Copyright (c) 2014 Spastic Muffin, LLC. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface UIImage (ReplacePixels)

// Ignores alpha channel of the color given, and returns an image replacing all visible (alpha > 0) pixels with the given color.
- (UIImage *) replaceVisiblePixelsWith: (UIColor *) color;

@end
