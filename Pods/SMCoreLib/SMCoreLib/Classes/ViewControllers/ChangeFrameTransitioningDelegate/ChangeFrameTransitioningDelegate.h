//
//  ChangeFrameTransitioningDelegate.h
//  TestPresentationController
//
//  Created by Christopher Prince on 9/21/14.
//  Copyright (c) 2014 Spastic Muffin, LLC. All rights reserved.
//

// For iOS8 and later, use this to change the size/position of a view controller after it has been presented. See TextPresentationController example. This presents the view controller at the center of the parent vc.
// 6/28/15; The docs appear to say that UIViewControllerTransitioningDelegate should work on iOS7, but I just ran a test with my SMModal (modified to run) with iOS7 and it certainly doesn't work immediately. The modal size was full screen.

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@interface ChangeFrameTransitioningDelegate : NSObject<UIViewControllerTransitioningDelegate>

// The frame gives the the size and position that the UIPresentationController used by this class will use when its frameOfPresentedViewInContainerView method is called. So, this is the size and position that your view controller will have.
- (instancetype) initWithFrame: (CGRect) frame;

// Needed when the keyboard disappears. Change the presented view back to the center of the window.
- (void) recenterThePresentedView;

// The UIPresentationController used by this class.
@property (nonatomic, strong, readonly) UIPresentationController *presentationController;

// The center of the presented view.
@property (nonatomic) CGPoint center;

// The center of the presented view.
@property (nonatomic) CGSize size;

// Defaults to YES.
@property (nonatomic) BOOL allowBackgroundTapDismiss;

@end
