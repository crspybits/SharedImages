//
//  SMEdgeInsetLabel.m
//  Catsy
//
//  Created by Christopher Prince on 9/14/15.
//  Copyright © 2015 Spastic Muffin, LLC. All rights reserved.
//

#import "SMEdgeInsetLabel.h"

// Code from http://stackoverflow.com/questions/3476646/uilabel-text-margin

@implementation SMEdgeInsetLabel

- (id)initWithFrame:(CGRect)frame{
    self = [super initWithFrame:frame];
    if (self) {
        self.edgeInsets = UIEdgeInsetsMake(0, 0, 0, 0);
    }
    return self;
}

- (void)drawTextInRect:(CGRect)rect {
    [super drawTextInRect:UIEdgeInsetsInsetRect(rect, self.edgeInsets)];
}

- (CGSize)intrinsicContentSize
{
    CGSize size = [super intrinsicContentSize];
    size.width  += self.edgeInsets.left + self.edgeInsets.right;
    size.height += self.edgeInsets.top + self.edgeInsets.bottom;
    return size;
}

@end
