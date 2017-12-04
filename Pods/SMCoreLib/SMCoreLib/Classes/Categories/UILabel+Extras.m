//
//  UILabel+Extras.m
//  Petunia
//
//  Created by Christopher Prince on 4/13/14.
//  Copyright (c) 2014 Spastic Muffin, LLC. All rights reserved.
//

#import "UILabel+Extras.h"
#import "UIView+Extras.h"

@implementation UILabel (Extras)

- (void) minimizeHeightGivenMaxHeight: (CGFloat) maxHeight;
{
    CGFloat currWidth = self.frameWidth;
    
    CGSize size = [self sizeThatFits:CGSizeMake(currWidth, MAXFLOAT)];
    if (size.height > maxHeight) {
        size.height = maxHeight;
    }
    
    CGRect frame = self.frame;
    frame.size.height = size.height;
    self.frame = frame;    
}

@end
