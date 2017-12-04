//
//  UITableViewCell+Extras.m
//  Petunia
//
//  Created by Christopher Prince on 9/14/14.
//  Copyright (c) 2014 Spastic Muffin, LLC. All rights reserved.
//

#import "UITableViewCell+Extras.h"
#import "SPASLog.h"

@implementation UITableViewCell (Extras)

- (void) makeFullLengthSeparator;
{
    // iOS8
    // http://stackoverflow.com/questions/18365049/is-there-a-way-to-make-uitableview-cells-in-ios-7-not-have-a-line-break-in-the-s
    if ([self respondsToSelector:@selector(layoutMargins)]) {
        self.layoutMargins = UIEdgeInsetsZero;
    }
    
    if ([self respondsToSelector:@selector(setSeparatorInset:)]) {
        [self setSeparatorInset:UIEdgeInsetsZero];
    }
}

- (NSIndexPath *) indexPath;
{
    SPASLogDetail(@"%@", [self.superview class]);
    SPASLogDetail(@"%@", [self.superview.superview class]);
    return [[self getTableView] indexPathForCell:self];
}

// See http://stackoverflow.com/questions/15711889/how-to-get-uitableviewcell-indexpath-from-the-cell
- (UITableView *)getTableView {
    // get the superview of this class, note the camel-case V to differentiate
    // from the class' superview property.
    UIView *superView = self.superview;
    
    /*
     check to see that *superView != nil* (if it is then we've walked up the
     entire chain of views without finding a UITableView object) and whether
     the superView is a UITableView.
     */
    while (superView && ![[superView class] isSubclassOfClass:[UITableView class]]) {
        superView = superView.superview;
    }
    
    // if superView != nil, then it means we found the UITableView that contains
    // the cell.
    if (superView) {
        // cast the object and return
        return (UITableView *)superView;
    }
    
    // we did not find any UITableView
    return nil;
}

@end
