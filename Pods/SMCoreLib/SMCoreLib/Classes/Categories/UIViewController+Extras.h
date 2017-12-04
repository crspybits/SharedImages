//
//  UIViewController+Extras.h
//  Petunia
//
//  Created by Christopher Prince on 7/26/14.
//  Copyright (c) 2014 Spastic Muffin, LLC. All rights reserved.
//

// In iOS7, when the init method is called, viewDidLoad is immediately called. But, with iOS6, viewDidLoad is called when the view is presented for the first time. To deal with this, I'm going to force viewDidLoad to be called in the init method in iOS6.
// 5/20/15; I'm not sure about that statement. It seems like in iOS7 this delay of viewDidLoad occurs sometimes too. See note with this same date below.
// See also: https://discussions.apple.com/message/23121354
// and http://stackoverflow.com/questions/12703659/force-viewdidload-to-fire-on-ios

#define ConfigureViewController(X) {\
            [self view];\
            SPASLog(@"ConfigureViewController");\
            X;\
        }

/* Example usage:
 
    ConfigureViewController({
        // View controller configuration code.
        // Put this at the very bottom of your view controller init method(s).
    });

 */

// 5/20/15; See also initWithParentViewController: in Petunia HomeCareDataEntry.m for a rationale why you may not want to use initWithNibName for your initializations.

#import <UIKit/UIKit.h>

@interface UIViewController (Extras)

// Because of status bar/nav bar starting position (Y coord) issues of view controller in iOS7 or higher. Do you have to be using a nav controller for this to work?
- (void) correctStartingPosition;

// Using unusual names for these two because I was having name conflicts with MainMenuViewController.
- (void) changeStatusBarColor:(UIColor *)statusBarColor;
@property (nonatomic, strong, readonly) UIColor *getStatusBarColor;

// Doesn't distinguish between left/right landscape and right sideup/upside down portrait. If view controller orientation is portrait (left or right) returns YES; otherwise, returns NO.
@property (nonatomic, readonly) BOOL orientationIsPortrait;

// Upside down portrait and landscape right are considered inverted.
@property (nonatomic, readonly) BOOL orientationIsInverted;

// In order to have inverted portrait on iPhone, it seems  you have to have this. It's not sufficient to have the Info.plist with all orientations, or the method in the app delegate that gives the orientation mask. See http://stackoverflow.com/questions/12542472/why-iphone-5-doesnt-rotate-to-upsidedown?lq=1
- (NSUInteger)supportedInterfaceOrientations;

@end
