//
//  SMModal.m
//  Petunia
//
//  Created by Christopher Prince on 5/28/15.
//  Copyright (c) 2015 Spastic Muffin, LLC. All rights reserved.
//

#import "SMModal.h"
#import "UIDevice+Extras.h"
#import "SMAppearance.h"
#import "SMRotation.h"
#import "UIViewController+Extras.h"
#import "UIView+Extras.h"
#import "SPASLog.h"
#import "SMAssert.h"
#import "NSObject+Extras.h"

// For disablesAutomaticKeyboardDismissal
// Resolving bug #P118.
#import "UINavigationController+Extras.h"


@interface SMModal()
@property (nonatomic, strong) UINavigationController *popupNavController;
@end

@implementation SMModal

- (instancetype) initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil;
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    
    if (self) {
        self.roundedCorners = YES;
    }
    
    return self;
}

- (void) show;
{
    [self showWithCompletion:nil];
}

- (void) setLeftBarButtonItems:(NSArray *)leftBarButtonItems;
{
    _leftBarButtonItems = leftBarButtonItems;
    self.navigationItem.leftBarButtonItems = self.leftBarButtonItems;
}

- (void) setRightBarButtonItems:(NSArray *)rightBarButtonItems;
{
    _rightBarButtonItems = rightBarButtonItems;
    self.navigationItem.rightBarButtonItems = self.rightBarButtonItems;
}

// For repositioning the popup http://stackoverflow.com/questions/19493865/resize-modalviewcontroller-and-position-it-at-center-in-ios-7

- (UINavigationController *) popupNavController;
{
    if (!_popupNavController) {
        _popupNavController = [[UINavigationController alloc] initWithRootViewController:self];
    }
    return _popupNavController;
}

- (void) showInFullScreen;
{
    [self showInFullScreenWithCompletion:nil];
}

// 7/5/15; I just spent a stupid amount of time with an issue on iPhone. The start of the issue was that I was having problems rotating a "modal" (displayed full screen) into landscape and then back to portrait. In this case, the nav bar was getting pushed up, and not getting displayed under the status bar when returning to portrait. I tried adjusting the Y coord of the nav bar, but that didn't resolve the issue because I then ran into issues with the coloring of the status bar. The trick seems to be not to try to force the issue so much and instead to just present the "modal" VC using more standard techniques, i.e., presentViewController: below. I tried using UINavigationController methods to push the VC, but was having problems there with replacing the "Back" button.
- (void) showInFullScreenWithCompletion: (void (^)(void)) completion;
{
    [self showCommonFromNavController:self.popupNavController];
    [self.modalParentVC presentViewController:self.popupNavController animated:YES completion:completion];
}

- (void) showCommonFromNavController: (UINavigationController *) navController;
{
    // In case these were not established yet.
    self.rightBarButtonItems = self.rightBarButtonItems;
    self.leftBarButtonItems = self.leftBarButtonItems;
    
    // Automatically positions objects below nav bar:
    // http://stackoverflow.com/questions/19024031/ios7-webview-initial-scroll-position-under-navigation-bar
    navController.navigationBar.translucent = false;
    
    // 7/23/15; With version 1.3.2.3 submitted to the app store, the following line of code was not working to hide the nav bar with iOS8.4. The fix was [1]. I swear I had this working previously, prior to iOS8.4. See also comments about iOS8 in http://stackoverflow.com/questions/25866743/show-hide-navigationbar-when-view-is-pushed-popped-in-ios-8
    // navController.navigationBar.hidden = self.hidesNavBar;
}

- (void) viewWillAppear:(BOOL)animated;
{
    [super viewWillAppear:animated];
    
    // See [1].
    [self.navigationController setNavigationBarHidden:self.hidesNavBar];
}

- (void) showWithCompletion: (void (^)(void)) completion;
{
    [self showCommonFromNavController:self.popupNavController];
    
    if ([UIDevice iOS8OrLater]) {
        _changeFrameTd = [[ChangeFrameTransitioningDelegate alloc] initWithFrame:_ourFrame];
        self.popupNavController.modalPresentationStyle = UIModalPresentationCustom;
        self.popupNavController.transitioningDelegate = _changeFrameTd;
    } else {
        // See viewWillAppear-- change the frame there.
        self.popupNavController.modalPresentationStyle = UIModalPresentationFormSheet;
    }
    
    self.popupNavController.modalTransitionStyle = UIModalTransitionStyleCoverVertical;
    
    if ([UIDevice iOS8OrLater]) {
        [self.modalParentVC presentViewController:self.popupNavController animated:YES completion:completion];
    } else {
        // For some reason, I wasn't getting the VC positioned exactly in the center, which I needed for later keyboard related animations.
        // Start the data entry VC off screen at the bottom, and animate it on, to the center of the screen.
        
        [self.modalParentVC presentViewController:self.popupNavController animated:NO completion:nil];
        self.popupNavController.view.superview.boundsSize = _ourFrame.size;

        // Position the Data Entry vc initially off screen to the bottom.
        // 5/21/15; I'm having a further problem that when rotated into inverted portrait or inverted landscape, the Data Entry VC animates in from the *top* as opposed to the bottom as typical. I believe this goes hand in hand with issue [3]. I think CENTER is not actually rotated.
        CGPoint center = CGPointMake([SMRotation screenCenter].x, [SMRotation screenSize].height+_ourFrame.size.height);
        if ([self orientationIsInverted]) {
            center.y = -center.y;
        }
        
        self.center = center;
        
        [UIView animateWithDuration:0.25 delay:0 options:UIViewAnimationOptionCurveEaseIn animations:^{
            self.center = [SMRotation screenCenter];
        } completion:^(BOOL finished) {
            if (completion) {
                completion();
            }
        }];
    }
}

- (void)viewWillLayoutSubviews
{
    [super viewWillLayoutSubviews];
    
    // For iOS7, it seems necessary to have this corner rounding in viewWillLayoutSubviews.
    // For iOS6, if I hide the nav bar, I'm getting only the bottom corners rounded, and not the top. Just don't worry about corner rounding with iOS6 when I hide the nav bar. BUT: This only seems to occur if you have a border around the modal. Lesson: With iOS6, don't put a border around the modals. Plus, with iOS6, the system default seems to be to have modals with rounded corners.

    if (self.roundedCorners) {
        //if (!self.hidesNavBar || [UIDevice ios7OrLater]) {
        [[SMAppearance session] roundCornersOnModalWithView:self.popupNavController.view];
        //}
    }
    
    SPASLogDetail(@"self.view.frame: %@", NSStringFromCGRect(self.view.frame));
    SPASLogDetail(@"self.navigationController.view.frame: %@", NSStringFromCGRect(self.navigationController.view.frame));
    SPASLogDetail(@"self.navigationController.navigationBar.frame %@", NSStringFromCGRect(self.navigationController.navigationBar.frame));
}

// 9/20/14; This code was working in iOS6 and iOS7, but something has changed (how surprising!) with iOS8. And the DataEntry controller is not moving up any more.
// For repositioning the popup http://stackoverflow.com/questions/19493865/resize-modalviewcontroller-and-position-it-at-center-in-ios-7
// 9/20/14; I'm trying to resolve this issue. See http://stackoverflow.com/questions/25957343/moving-a-modally-presented-uiviewcontroller-up-when-keyboard-appears-on-ipad-wit

// 9/20/14; Prior to iOS8
#define CENTER self.popupNavController.view.superview.center
#define CENTER_VIEW self.popupNavController.view.superview

- (CGPoint) center
{
    CGPoint center;
    
    if ([UIDevice iOS8OrLater]) {
        center = _changeFrameTd.center;
    }
    else {
        center = CENTER;
    }
    
    return center;
}

// 7/2/15; See http://stackoverflow.com/questions/31196080/moving-uiviewcontroller-modal-up-when-keyboard-appears-independent-of-rotation-w for my solution to the problem of moving the modal with iOS7 when the keyboard appears.
- (void) setCenter:(CGPoint)center
{
    // 7/2/15; Note that CGPointApplyAffineTransform, or conversion of points using views (e.g., convertPoint:fromView:), did not prove useful to resolve the problem I've been having with <= iOS7. E.g., Bug #P122.
#ifdef DEBUG
    SPASLogDetail(@"%@", NSStringFromCGAffineTransform(CENTER_VIEW.transform));
    SPASLogDetail(@"center: %@", NSStringFromCGPoint(center));
    CGPoint newCenter = CGPointApplyAffineTransform (center, CENTER_VIEW.transform);
    SPASLogDetail(@"newCenter: %@", NSStringFromCGPoint(newCenter));
#endif
    
    if ([UIDevice iOS8OrLater]) {
        _changeFrameTd.center = center;
    }
    else {
        // [3] This is pretty odd. But, in lanscape for iOS <= 7, we have to swap the x/y coords. This is also why I'm not using the transitioning delegate with iOS7.
        // See also http://stackoverflow.com/questions/2457947/how-to-resize-a-uimodalpresentationformsheet?lq=1

        if ([SMRotation session].isLandscape) {
            CENTER = CGPointMake(center.y, center.x);
        }
        else {
            CENTER = center;
        }
    }
}

- (void) adjustCenterUsingDx: (CGFloat) dx andDy: (CGFloat) dy;
{
    CGPoint newCenter;
    
    if ([UIDevice iOS9OrLater]) {
        newCenter = [SMRotation screenCenter];
    } else if ([UIDevice iOS8OrLater]) {
        newCenter = self.center;
    }
    else {
        newCenter = [SMRotation screenCenter];
        
        // Bug #P122. Why does this work, and the CGPointApplyAffineTransform not work? I don't know.
        if ([SMRotation session].isInverted) {
            dy = -dy;
        }
    }
    
    newCenter.x += dx;
    newCenter.y += dy;
    
    // self.center takes care of any x/y swapping for iOS7
    self.center = newCenter;
}

- (CGSize) modalSize;
{
    AssertIf(![UIDevice iOS8OrLater], @"Must be iOS8 or later");
    if (_changeFrameTd) {
        return _changeFrameTd.size;
    } else {
        return _ourFrame.size;
    }
}

- (void) setModalSize:(CGSize)size;
{
    AssertIf(![UIDevice iOS8OrLater], @"Must be iOS8 or later");
    if (_changeFrameTd) {
        _changeFrameTd.size = size;
    } else {
        _ourFrame.size = size;
    }
}

- (void) cleanup;
{
// See http://fuckingclangwarnings.com for list of warnings.
// I'm just ignoring this warning because this is a cleanup/deallocation step.
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wnonnull"
    // 6/24/15; This is only here because I had memory leaks bridging this class to Swift. This seems to be fixing it.
    self.popupNavController.viewControllers = nil;
#pragma clang diagnostic pop
    
    // 9/8/14; Because we have a strong reference.
    self.popupNavController = nil;
    
    SPASLogDetail(@"self.modalParentVC.presentedViewController: %@", self.modalParentVC.presentedViewController);
    
    SPASLogDetail(@"arcReferenceCount: %li", (long)[self arcReferenceCount]);
}

- (void) close;
{
    [self closeWithCompletion:nil];
}

- (void) closeWithCompletion: (void (^)(void)) completion;
{
    if (self.willClose) {
        self.willClose();
    }
    
    [self dismissViewControllerAnimated:YES completion:^{
        if (completion) {
            completion();
        }
        [self cleanup];
    }];
}

- (void) dealloc;
{
    SPASLogDetail(@"dealloc");
}

#pragma mark - Methods for subclasses

- (void) setDefaultSize; // sets _ourFrame
{
    _ourFrame = CGRectMake(0, 0, SM_MODAL_VC_WIDTH, SM_MODAL_VC_HEIGHT + [[SMAppearance session] navBarHeight]);
}

- (void) setSize:(CGSize)size;
{
    _ourFrame = CGRectMake(0, 0, size.width, size.height);
}

- (CGFloat) bottomMargin;
{
    CGFloat result = 0.0;
    if ([UIDevice iOS8OrLater]) {
        UIWindow *window = [[[UIApplication sharedApplication] windows]objectAtIndex:0];
        CGFloat maxYDataEntry = self.popupNavController.view.frameMaxY;
        result = window.frameHeight - maxYDataEntry;
    }
    else {
        BadMojo("Not defined for <= iOS7")
    }
    
    return result;
}

#pragma mark -

@end
