//
//  UITableView+Extras.m
//  Petunia
//
//  Created by Christopher Prince on 8/28/14.
//  Copyright (c) 2014 Spastic Muffin, LLC. All rights reserved.
//

#import "UITableView+Extras.h"
#import "TimedCallback.h"
#import "UIView+Extras.h"

@implementation UITableView (Extras)

// Some code from http://stackoverflow.com/questions/4926705/is-there-a-way-of-animating-a-uitableviewcell-so-that-the-row-flashes-briefly-to/12293293#12293293
- (void) flashRow: (NSUInteger) rowNumber withDuration: (NSTimeInterval) durationOfFlash;
{
    [self flashRow:rowNumber withDuration:durationOfFlash andCompletion:nil];
}

- (void) flashRow: (NSUInteger) rowNumber withDuration: (NSTimeInterval) durationOfFlash andCompletion: (void (^)(void)) callback;
{
    NSIndexPath *indexPathOfRow = [NSIndexPath indexPathForRow:rowNumber inSection:0];
    
    if (0.0 == durationOfFlash) {
        // Use Apple's defaults for duration...
        [UIView animateWithDuration:0.0
                              delay:0.0
                            options:UIViewAnimationOptionAllowUserInteraction
                         animations:^void() {
                             [[self cellForRowAtIndexPath:indexPathOfRow] setHighlighted:YES animated:YES];
                         }
                         completion:^(BOOL finished) {
                             [[self cellForRowAtIndexPath:indexPathOfRow] setHighlighted:NO animated:YES];
                             if (callback) {
                                 callback();
                             }
                         }];
        return;
    } else if (durationOfFlash < 0.0) {
        durationOfFlash = DEFAULT_DURATION_OF_FLASH;
    }
    
    [[self cellForRowAtIndexPath:indexPathOfRow] setHighlighted:YES animated:YES];
    
    // 1) Do the flash for a time interval, 2) Do the de-Flash animation, then 3) do the callback.
    (void) [[TimedCallback alloc] initWithDuration:durationOfFlash andCallback:^{
        [UIView performAnimationSequence:
         @[^() {
                [[self cellForRowAtIndexPath:indexPathOfRow] setHighlighted:NO animated:YES];
            }]
            andThenCompletion:^{
                if (callback) {
                    callback();
                }
            }];
    }];
}

- (void) makeFullLengthSeparator;
{
    // iOS8
    // http://stackoverflow.com/questions/18365049/is-there-a-way-to-make-uitableview-cells-in-ios-7-not-have-a-line-break-in-the-s
    if ([self respondsToSelector:@selector(layoutMargins)]) {
        self.layoutMargins = UIEdgeInsetsZero;
    }

    // Needed for iOS7 and iOS8
    // http://stackoverflow.com/questions/18773239/how-to-fix-uitableview-separator-on-ios-7
    if ([self respondsToSelector:@selector(setSeparatorInset:)]) {
        [self setSeparatorInset:UIEdgeInsetsZero];
    }
    
    // iOS9
    // 12/18/15; Bug #P142. For some reason, when in landscape, the textLabel of a standard UITableViewCell (a) isn't wide enough, and (b) is positioned too far in from the left (X is too large).
    // See http://stackoverflow.com/questions/31537196/ios-9-uitableview-separators-insets-significant-left-margin
    // See also readableContentGuide in https://developer.apple.com/library/ios/documentation/UIKit/Reference/UIView_Class/#//apple_ref/occ/instp/UIView/readableContentGuide
    if ([self respondsToSelector:@selector(setCellLayoutMarginsFollowReadableWidth:)])
    {
        self.cellLayoutMarginsFollowReadableWidth = NO;
    }
}

@end
