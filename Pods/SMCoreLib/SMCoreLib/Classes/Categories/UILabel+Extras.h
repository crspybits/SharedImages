//
//  UILabel+Extras.h
//  Petunia
//
//  Created by Christopher Prince on 4/13/14.
//  Copyright (c) 2014 Spastic Muffin, LLC. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface UILabel (Extras)

// If you are trying to remove the padding/margin around a UILabel, see the class (in Common/Views) SMEdgeInsetLabel.

// Given that you have assigned text to the label, and given it a width. Does not alter x, y or width.
- (void) minimizeHeightGivenMaxHeight: (CGFloat) maxHeight;

@end
