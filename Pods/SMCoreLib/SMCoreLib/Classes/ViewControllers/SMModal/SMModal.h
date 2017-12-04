//
//  SMModal.h
//  Petunia
//
//  Created by Christopher Prince on 5/28/15.
//  Copyright (c) 2015 Spastic Muffin, LLC. All rights reserved.
//

// A variable size, and repositionable modal with optional nav bar.

#import <UIKit/UIKit.h>
#import "ChangeFrameTransitioningDelegate.h"

@interface SMModal : UIViewController {
    @protected
        // Size and initial position of modal; change .center property to change the position of the modal after showing. Subclass needs to set this. Change the .size property to change the size after showing.
        CGRect _ourFrame;
}

// Subclass needs to first establish _ourFrame and _myParent beforehand. Displays the modal VC in the center of the screen.
// Objects in self.view are automatically positioned by the nav bar.
- (void) show;
- (void) showWithCompletion: (void (^)(void)) completion;

// I've been running into problems showing a modal in full-screen. So, use these methods if presenting the VC in full screen on iPhone.
- (void) showInFullScreen;
- (void) showInFullScreenWithCompletion: (void (^)(void)) completion;

// Close the modal VC.
- (void) close;
- (void) closeWithCompletion: (void (^)(void)) completion;

// Call when done with this instance. Called automatically in the close methods.
- (void) cleanup;

// Set this before showing to hide nav bar.
@property (nonatomic) BOOL hidesNavBar;

// To be placed on the nav bar when the modal appears.
@property (nonatomic, strong) NSArray *rightBarButtonItems;
@property (nonatomic, strong) NSArray *leftBarButtonItems;

// To deal with iOS <= 7 issue in landscape mode. And enables repositioning of modal after display. For <= iOS7, this is only useful for repositioning the modal to the exact center of the screen.
@property (nonatomic) CGPoint center;

// Adjust from self.center (>= iOS8) or from [SMRotation screenCenter] (<= iOS7). This was needed because I was having problems adjusting the position of the modal when the keyboard appears in iOS7. E.g., See bug #P122.
- (void) adjustCenterUsingDx: (CGFloat) dx andDy: (CGFloat) dy;

// Only for iOS8 or later. Height includes navigation bar height.
@property (nonatomic) CGSize modalSize;

@property (nonatomic, strong, readonly) UINavigationController *popupNavController;

// Called during the close process, if given.
@property (nonatomic, strong) void (^willClose)(void);

// Default is YES. Useful to turn this off if you are using SMModal on iPhone, and presenting the "modal" in full screen.
@property (nonatomic) BOOL roundedCorners;

// Methods & properties for subclasses
- (void) setDefaultSize; // sets _ourFrame
// Takes the size exactly; nav bar must fit within this.
- (void) setSize: (CGSize) size; // sets _ourFrame

// For moving the modal up when the keyboard appears; only defined for >= iOS8. Use your own code for <= iOS7.
- (CGFloat) bottomMargin;

// Exposed this as a property for Swift.
@property (nonatomic, strong) ChangeFrameTransitioningDelegate *changeFrameTd;

// Subclasses need to set this.
// because I was having problems accessing protected member from a Swift subclass.
@property (nonatomic, weak) UIViewController *modalParentVC;

@end
