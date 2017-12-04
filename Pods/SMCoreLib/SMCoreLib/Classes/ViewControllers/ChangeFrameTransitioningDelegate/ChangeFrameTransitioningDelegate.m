//
//  ChangeFrameTransitioningDelegate.m
//  TestPresentationController
//
//  Created by Christopher Prince on 9/21/14.
//  Copyright (c) 2014 Spastic Muffin, LLC. All rights reserved.
//

// Some help from http://stackoverflow.com/questions/25903412/editing-bounds-of-uiview-when-presenting-hides-keyboard-in-ios-8
// http://stackoverflow.com/questions/25811199/ios-8-change-the-size-of-presented-modal-view-controller
// Some code from https://developer.apple.com/devcenter/download.action?path=/wwdc_2014/wwdc_2014_sample_code/lookinsidepresentationcontrollersadaptivityandcustomanimatorobjects.zip (though, beware, this example doesn't work straight out of the box).
// And see http://stackoverflow.com/questions/25957343/moving-a-modally-presented-uiviewcontroller-up-when-keyboard-appears-on-ipad-wit

#ifndef SPASLogDetail
#define SPASLogDetail NSLog
#endif

#import "ChangeFrameTransitioningDelegate.h"
#import "UIView+Extras.h"

@interface PresentationController : UIPresentationController
{
    UIView *_dimmingView;
}

- (void) recenterThePresentedView;

// This is the size and position that the PresentationController will use when its frameOfPresentedViewInContainerView method is called.
@property (nonatomic) CGRect currentFrame;

@property (nonatomic) CGPoint center;
@property (nonatomic) CGSize size;
@property (nonatomic) BOOL allowBackgroundTapDismiss;

@end

@implementation PresentationController

- (instancetype)initWithPresentedViewController:(UIViewController *)presentedViewController presentingViewController:(UIViewController *)presentingViewController;
{
    self = [super initWithPresentedViewController:presentedViewController presentingViewController:presentingViewController];
    // Some random default size.
    self.currentFrame = CGRectMake(0, 0, 100, 100);
    [self prepareDimmingView];
    self.allowBackgroundTapDismiss = YES;
    return self;
}

// 4/22/15; Added, for rotation.
- (void) viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator;
{
    CGSize increasedSize = size;
    // 4/22/15; I'm getting some odd effects: In a rotation transition from landscape to portrait, the RHS goes white momentarily, and from portrait to landscape, the bottom goes white momentarily. A hack, but increase the size of the dimming view to get around this.
    increasedSize.width *= 1.5;
    increasedSize.height *= 1.5;
    _dimmingView.frameSize = increasedSize;
    
    // There appears to be no transitionCoordinator available for this "transition". Therefore using the regular UIView animation, below.
    /*
    if([self.presentedViewController transitionCoordinator])
    {
        [[self.presentedViewController transitionCoordinator] animateAlongsideTransition:^(id<UIViewControllerTransitionCoordinatorContext> context) {
            recenterViewController();
        } completion:nil];
    }
    else
    {
        recenterViewController();
    }*/
    
    // 4/23/15; See [1]. Given that I've turned off resizing with the autoresizingMask, this has messed up the repositioning of the (x, y) coordinate of the presentedViewController. Make up for that here.
    [UIView animateWithDuration: coordinator.transitionDuration animations:^{
        // I'm assuming the size here refers to the entire window.
        [self setCenterOfPresentedViewWithSize:size];
    } completion:nil];
}

- (void) setCenterOfPresentedViewWithSize: (CGSize) size;
{
    CGPoint center = CGPointMake(size.width/2.0, size.height/2.0);
    self.presentedView.center = center;
}

- (void) recenterThePresentedView;
{
    [self setCenterOfPresentedViewWithSize:[self containerView].frameSize];
}

- (void)presentationTransitionWillBegin
{
    UIView* containerView = [self containerView];
    
    // 4/23/15; So, this seems to be related to my modal view resizing problem. When I disable autoresizesSubviews, I stop the resizing during the rotation. HOWEVER, this is at the price of two additional problems: (a) the (x, y) coordinate of the modal stops being changed during the rotation, and (b) the animation of the background (_dimmingView?) starts looking funky during the rotation. WHICH makes sense. The containerView size is the full window.
    //containerView.autoresizesSubviews = NO;
    
    UIViewController* presentedViewController = [self presentedViewController];
    
    // 4/25/15; This is to deal with an odd condition, where the presented (modal) view controller disappears, the app is rotated, then the view controller reappears. Happens in the Pet Care tab when an image is presented from a Data Entry modal, the app is rotated, then the image is dismissed.
    [self recenterThePresentedView];
    
    // [1] 4/23/15; This is better. The _dimmingView animation is preserved. The (x, y) position of the presentedViewController, however isn't right after the rotation.
    presentedViewController.view.autoresizingMask = UIViewAutoresizingNone;
    
    [_dimmingView setFrame:[containerView bounds]];
    [_dimmingView setAlpha:0.0];
    
    [containerView insertSubview:_dimmingView atIndex:0];
    
    void (^setAlpha)() = ^{
        [_dimmingView setAlpha:1.0];
    };
    
    if([presentedViewController transitionCoordinator])
    {
        [[presentedViewController transitionCoordinator] animateAlongsideTransition:^(id<UIViewControllerTransitionCoordinatorContext> context) {
            setAlpha();
        } completion:^(id<UIViewControllerTransitionCoordinatorContext> context) {
            SPASLogDetail(@"self.presentedViewController.view: %@", self.presentedViewController.view);
        }];
    }
    else
    {
        setAlpha();
    }
}

- (void)dismissalTransitionWillBegin
{
    void (^resetAlpha)() = ^{
        [_dimmingView setAlpha:0.0];
    };
    
    if([[self presentedViewController] transitionCoordinator])
    {
        [[[self presentedViewController] transitionCoordinator] animateAlongsideTransition:^(id<UIViewControllerTransitionCoordinatorContext> context) {
            resetAlpha();
        } completion:nil];
    }
    else
    {
        resetAlpha();
    }
}

// Subclasses method of UIPresentationController
- (CGRect)frameOfPresentedViewInContainerView;
{
    SPASLogDetail(@"frameOfPresentedViewInContainerView: %@", NSStringFromCGRect(self.currentFrame));
    return self.currentFrame;
}

- (CGRect) currentFrame;
{
    return self.presentedView.frame;
}

- (void) setCurrentFrame:(CGRect)currentFrame
{
    // This is the important part for changing the frame of the presented view controller *after* the view is presented. For some odd reason, its not right to change the frame of the containerView.
    self.presentedView.frame = currentFrame;
}

- (CGPoint) center;
{
    return self.presentedView.center;
}

- (void) setCenter:(CGPoint)center;
{
    self.presentedView.center = center;
}

- (CGSize) size;
{
    return self.presentedView.boundsSize;
}

- (void) setSize:(CGSize)size;
{
    self.presentedView.boundsSize = size;
}

- (void) containerViewWillLayoutSubviews;
{
    SPASLogDetail(@"containerViewWillLayoutSubviews");
}

- (void)prepareDimmingView
{
    _dimmingView = [[UIView alloc] init];
    [_dimmingView setBackgroundColor:[UIColor colorWithWhite:0.0 alpha:0.4]];
    [_dimmingView setAlpha:0.0];
    
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(dimmingViewTapped:)];
    [_dimmingView addGestureRecognizer:tap];
}

- (void)dimmingViewTapped:(UIGestureRecognizer *)gesture
{
    if (self.allowBackgroundTapDismiss && [gesture state] == UIGestureRecognizerStateRecognized)
    {
        [[self presentingViewController] dismissViewControllerAnimated:YES completion:NULL];
    }
}

@end

@interface ChangeFrameTransitioningDelegate()
@property (nonatomic, strong) PresentationController *presentationController;
@property (nonatomic) CGRect initalFrame;
@end

@implementation ChangeFrameTransitioningDelegate

- (instancetype) initWithFrame: (CGRect) frame;
{
    self = [super init];
    if (self) {
        self.initalFrame = frame;
    }
    return self;
}

- (void) recenterThePresentedView;
{
    [(PresentationController * )self.presentationController recenterThePresentedView];
}

- (UIPresentationController *)presentationControllerForPresentedViewController:(UIViewController *)presented presentingViewController:(UIViewController *)presenting sourceViewController:(UIViewController *)source
{
    self.presentationController = [[PresentationController alloc] initWithPresentedViewController:presented presentingViewController:presenting];
    ((PresentationController *) self.presentationController).currentFrame = self.initalFrame;
    return self.presentationController;
}

- (CGPoint) center;
{
    return ((PresentationController *) self.presentationController).center ;
}

- (void) setCenter:(CGPoint)center;
{
    ((PresentationController *) self.presentationController).center = center;
}

- (CGSize) size;
{
    return ((PresentationController *) self.presentationController).size;
}

- (void) setSize:(CGSize)size;
{
    ((PresentationController *) self.presentationController).size = size;
}

- (void) setAllowBackgroundTapDismiss:(BOOL)allowBackgroundTapDismiss;
{
    ((PresentationController *) self.presentationController).allowBackgroundTapDismiss = allowBackgroundTapDismiss;
}

- (BOOL) allowBackgroundTapDismiss;
{
    return ((PresentationController *) self.presentationController).allowBackgroundTapDismiss;
}

@end
