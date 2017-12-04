//
//  SMAppearance.h
//  Petunia
//
//  Created by Christopher Prince on 4/25/15.
//  Copyright (c) 2015 Spastic Muffin, LLC. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

// E.g., dimensions for presenting a modal data entry view controller
// Without nav bar height
#define SM_MODAL_VC_HEIGHT 576
#define SM_MODAL_VC_WIDTH 540

@interface SMAppearance : NSObject

+ (instancetype) session;

/* Apply this in the following manner:
- (void) viewWillLayoutSubviews;
{
    [super viewWillLayoutSubviews];
    [[SMAppearance session] roundCornersOnModalWithView:self.navigationController.view];
}
 */
- (void) roundCornersOnModalWithView: (UIView *) view;

// TODO: This doesn't take into account the fact that the nav bar height changes on iPhone when in Landscape: e.g.. 44 pts in portrait and 32 pts in landscape.
@property (nonatomic, readonly) CGFloat navBarHeight;

@property (nonatomic, readonly) CGFloat statusBarHeight;

// E.g., for toolbar's on the top of the keyboard.
@property (nonatomic, readonly) CGFloat toolBarHeight;

// General: Each of these is to be set in a particular app, e.g., at launch.

// Global status bar color.
@property (nonatomic, strong) UIColor *statusBarColor;

@property (nonatomic, strong) NSString *mainFontName;

@end
