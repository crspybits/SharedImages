//
//  UITableViewCell+Extras.h
//  Petunia
//
//  Created by Christopher Prince on 9/14/14.
//  Copyright (c) 2014 Spastic Muffin, LLC. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface UITableViewCell (Extras)

// For iOS8; See the same named UITableView category method too!
- (void) makeFullLengthSeparator;

// Sometimes a cell needs to know where it is. Call this from layoutSubviews. Will return nil if it can't figure it out.
- (NSIndexPath *) indexPath;

@end
