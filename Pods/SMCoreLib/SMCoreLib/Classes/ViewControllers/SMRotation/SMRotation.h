//
//  SMRotation.h
//  Petunia
//
//  Created by Christopher Prince on 5/10/15.
//  Copyright (c) 2015 Spastic Muffin, LLC. All rights reserved.
//

// The reason for this class is because I don't, in general, appear to be able to get willRotate notifications from iOS. UIDevice only seems to support didRotate notifications.

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "NSObject+TargetsAndSelectors.h"

@interface SMRotation : NSObject

+ (instancetype) session;

// Call this in viewDidLoad in your main view controller. Pass in self.interfaceOrientation from that VC. Or SMRotation.session().initializeWithOrientation( UIApplication.sharedApplication().statusBarOrientation)
- (void) initializeWithOrientation: (UIInterfaceOrientation) interfaceOrientation;

/*
 "If a view controller is not visible when an orientation change occurs, then the rotation methods are never called."
 https://developer.apple.com/library/ios/documentation/UIKit/Reference/UIViewController_Class/
 */
/* Call these back from the similarly named methods in your main view controller. Calls to these drive the callbacks for willRotate and didRotate below. Alternatively, you can use the following app delegate methods. HOWEVER, the timing of these methods differs from those in the view controller. I just came across an issue where didChangeStatusBarOrientation is called significantly before the analogous one on the view controller-- well before the rotation completed.
 
 func application(application: UIApplication, willChangeStatusBarOrientation newStatusBarOrientation: UIInterfaceOrientation, duration: NSTimeInterval) {
 
    SMRotation.session().viewControllerWillRotateToOrientation(newStatusBarOrientation)
    SMRotation.session().viewControllerWillAnimateRotationToOrientation(newStatusBarOrientation)
 }
 
 func application(application: UIApplication, didChangeStatusBarOrientation oldStatusBarOrientation: UIInterfaceOrientation) {
 
    SMRotation.session().viewControllerDidRotate()
 }
*/
// Also see notes on viewWillTransitionToSize in ViewController.swift in Catsy.
- (void) viewControllerWillAnimateRotationToOrientation: (UIInterfaceOrientation)toInterfaceOrientation;
- (void) viewControllerWillRotateToOrientation: (UIInterfaceOrientation)toInterfaceOrientation;
- (void) viewControllerDidRotate;

/*
// For >= iOS8
- (void) viewWillTransitionToSize: (CGSize) size;
- (void) viewDidTransitionToSize;
*/

// Independent of iOS version and dependent on orientation.
+ (CGSize) screenSize;
+ (CGPoint) screenCenter;

// UI Orientation is landscape or portrait. Will lead the actual orientation in time. I.e., updated with "willRotate" method.
@property (nonatomic, readonly) BOOL isLandscape;
@property (nonatomic, readonly) BOOL isPortrait;
// Upside down portrait and landscape right are considered inverted.
@property (nonatomic, readonly) BOOL isInverted;

// Is the width > height?
+ (BOOL) isLandscapeFrame: (CGRect) frame;
// Don't rely on the portrait sidedness or the landscape left/right.
+ (UIInterfaceOrientation) orientationOfSize:(CGSize) size;

// Useful with iOS7 and iOS6. Applies a transform to (the current transforms of) the view to rotate it to the current rotation orientation.
- (void) transformViewAccordingToOrientation: (UIView *) view;

// The angle of the current orientation. Used within transformViewAccordingToOrientation. Don't use for > iOS7.
- (CGFloat) angleOfOrientation;

// A simple width/height swap for the fromFrame. Origin's are just copied from the fromFrame.
+ (void) getLandscapeFrame: (CGRect *) landscapeFrame andPortraitFrame: (CGRect *) portraitFrame fromFrame: (CGRect) frame;

// Use these in other classes to get rotation callbacks. There are no parameters passed to the callbacks.
@property (nonatomic, strong, readonly) NSObject<TargetsAndSelectors> *willAnimateRotation;
@property (nonatomic, strong, readonly) NSObject<TargetsAndSelectors> *willRotate;
@property (nonatomic, strong, readonly) NSObject<TargetsAndSelectors> *didRotate;

/*
// These are passed a CGSize parameter. Only for >= iOS8.
@property (nonatomic, strong, readonly) NSObject<TargetsAndSelectors> *willAnimateRotationWithSize;
@property (nonatomic, strong, readonly) NSObject<TargetsAndSelectors> *willRotateWithSize;
*/

// Newly pushed UIInterfaceOrientationMask becomes the currentOrientationMask.
- (void) pushOrientationMask: (NSUInteger) newOrientationMask;
// The top mask on the stack is popped. The one below that (or defaultOrientationMask, if none) becomes the currentOrientationMask.
- (void) popOrientationMask;

// Default of the default is All
@property (nonatomic) UIInterfaceOrientationMask defaultOrientationMask;
@property (nonatomic, readonly) UIInterfaceOrientationMask currentOrientationMask;

/* The intent is that you will use the currentOrientationMask in the app delegate, e.g.,
 func application(application: UIApplication, supportedInterfaceOrientationsForWindow window: UIWindow?) -> Int {
 return Int(SMRotation.session().currentOrientationMask.rawValue);
 }
 */

@end
