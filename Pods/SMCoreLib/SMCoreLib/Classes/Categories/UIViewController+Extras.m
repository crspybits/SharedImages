//
//  UIViewController+Extras.m
//  Petunia
//
//  Created by Christopher Prince on 7/26/14.
//  Copyright (c) 2014 Spastic Muffin, LLC. All rights reserved.
//

#import "UIViewController+Extras.h"
#import <objc/runtime.h>
#import "UIDevice+Extras.h"
#import "SMAppearance.h"
#import "UIView+Extras.h"

// 12/2/15; Running into some problems getting V1 of UIView+Extras.h in Petunia instead of what we are now using and needing (V3). I think I only need this #import for the Common Framework, only import it then.
#ifdef SMCOMMONLIB
#import "UIView+Extras.h"
#endif

#import "SPASLog.h"

static char kStatusBarColorView;
static char kStatusBarColor;

@implementation UIViewController (Extras)

- (void) correctStartingPosition;
{
    // See http://stackoverflow.com/questions/18276248/ios-7-uiview-frame-issue and https://developer.apple.com/library/ios/documentation/userexperience/conceptual/transitionguide/AppearanceCustomization.html#//apple_ref/doc/uid/TP40013174-CH15-SW1
    if([UIViewController instancesRespondToSelector:@selector(edgesForExtendedLayout)]) {
        self.edgesForExtendedLayout=UIRectEdgeNone;
    }
    
    /* See also
     // http://stackoverflow.com/questions/19024031/ios7-webview-initial-scroll-position-under-navigation-bar
     _popupNavController.navigationBar.translucent = false;
     */
}

- (void) setStatusBarColorViewAssocObj:(UIView *) view;
{
    objc_setAssociatedObject(self, &kStatusBarColorView, view, OBJC_ASSOCIATION_RETAIN);
}

- (UIView *) statusBarColorViewAssocObj;
{
    return (UIView *) objc_getAssociatedObject(self, &kStatusBarColorView);
}

- (void) setStatusBarColorAssocObj:(UIColor *) color;
{
    objc_setAssociatedObject(self, &kStatusBarColor, color, OBJC_ASSOCIATION_RETAIN);
}

- (UIColor *) statusBarColorAssocObj;
{
    return (UIColor *) objc_getAssociatedObject(self, &kStatusBarColor);
}

- (UIColor *) getStatusBarColor;
{
    return [self statusBarColorAssocObj];
}

- (void) changeStatusBarColor:(UIColor *)statusBarColor;
{
    [self setStatusBarColorAssocObj:statusBarColor];
    
    UIView *statusBarColorView = [self statusBarColorViewAssocObj];
    if (statusBarColorView) {
        [statusBarColorView removeFromSuperview];
    }
    
    // I'm changing color of the status bar and the nav bar because one usability-evaluation person indicated that she didn't think the nav bar title, and left/right buttons didn't belonged to the app-- that they seemed like part of the device or part of iOS.
    // For iOS6, the nav bar is not white (as it is by default in iOS7), and so possibly it will be easier to tell that it's part of the app.
    if ([UIDevice ios7OrLater]) {
        if (statusBarColor) {
            // See also the app delegate, didFinishLaunchingWithOptions; this puts up a black status bar, and the white text of the status bar shows through.
            // 5/16/15; iOS7: self.navigationController.view hasn't always changed to the rotated size by this point. Use self.view.
            statusBarColorView = [[UIView alloc] initWithFrame:CGRectMake(0, 0,self.view.frameWidth, [SMAppearance session].statusBarHeight)];
            SPASLogDetail(@"self.navigationController: %@", self.navigationController.view);
            SPASLogDetail(@"self.view: %@", self.view);

            statusBarColorView.backgroundColor = statusBarColor;
            [self.navigationController.view addSubview:statusBarColorView];
            [self setStatusBarColorViewAssocObj:statusBarColorView];
        }
    }
}

- (BOOL) orientationIsPortrait;
{
    switch (self.interfaceOrientation) {
        case UIInterfaceOrientationPortrait:
        case UIInterfaceOrientationPortraitUpsideDown:
            return YES;
        
        case UIInterfaceOrientationUnknown:
        case UIInterfaceOrientationLandscapeLeft:
        case UIInterfaceOrientationLandscapeRight:
            return NO;
    }
}

- (BOOL) orientationIsInverted;
{
    switch (self.interfaceOrientation) {
        case UIInterfaceOrientationPortraitUpsideDown:
        case UIInterfaceOrientationLandscapeRight:
            return YES;
        
        case UIInterfaceOrientationPortrait:
        case UIInterfaceOrientationLandscapeLeft:
        case UIInterfaceOrientationUnknown:
            return NO;
    }
}

- (NSUInteger) supportedInterfaceOrientations {
    return UIInterfaceOrientationMaskAll;
}

@end
