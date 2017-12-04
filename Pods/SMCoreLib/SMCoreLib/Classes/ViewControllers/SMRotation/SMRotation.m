//
//  SMRotation.m
//  Petunia
//
//  Created by Christopher Prince on 5/10/15.
//  Copyright (c) 2015 Spastic Muffin, LLC. All rights reserved.
//

// See also http://stackoverflow.com/questions/13710789/uiactionsheet-showfromrect-autorotation/30177502#30177502

// And http://stackoverflow.com/questions/24150359/is-uiscreen-mainscreen-bounds-size-becoming-orientation-dependent-in-ios8

#import "SMRotation.h"
#import "UIDevice+Extras.h"
#import "NSObject+Extras.h"
#import "SMAssert.h"

@interface SMRotation()
@property (nonatomic, strong) NSObject<TargetsAndSelectors> *willRotate;
@property (nonatomic, strong) NSObject<TargetsAndSelectors> *didRotate;
@property (nonatomic, strong) NSObject<TargetsAndSelectors> *willAnimateRotation;
@property (nonatomic) UIInterfaceOrientation interfaceOrientation;
@property (nonatomic) UIInterfaceOrientationMask currentOrientationMask;
@property (nonatomic, strong) NSMutableArray *orientationMaskStack;
@end

@implementation SMRotation

+ (instancetype) session;
{
    static SMRotation* s_sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        s_sharedInstance = [self new];
        [s_sharedInstance setup];
    });
    
    return s_sharedInstance;
}

- (void) setup;
{
    self.willRotate = [NSObject new];
    [self.willRotate resetTargets];
    self.didRotate = [NSObject new];
    [self.didRotate resetTargets];
    self.willAnimateRotation = [NSObject new];
    [self.willAnimateRotation resetTargets];
    
    self.defaultOrientationMask = UIInterfaceOrientationMaskAll;
    self.currentOrientationMask = self.defaultOrientationMask;
    self.orientationMaskStack = [NSMutableArray new];
    
    // There does not appear to be a UIDeviceOrientationWillChangeNotification. The following notification is posted not just when the device rotates. If I just pick up my iPad, this gets fired.
    /*
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didRotateNotification:) name:UIDeviceOrientationDidChangeNotification object:nil];
    */
}

/*
- (void) didRotateNotification: (id) sender;
{
    SPASLogDetail(@"didRotateNotification: %@", sender);
}
 */

- (void) initializeWithOrientation: (UIInterfaceOrientation) interfaceOrientation;
{
    _interfaceOrientation = interfaceOrientation;
}

- (void) viewControllerWillAnimateRotationToOrientation: (UIInterfaceOrientation)toInterfaceOrientation;
{
    _interfaceOrientation = toInterfaceOrientation;
    
    [self.willAnimateRotation forEachTargetInCallbacksDo:^(id target, SEL selector, NSMutableDictionary *dict) {
        [target performVoidReturnSelector:selector];
    }];
}

- (void) viewControllerWillRotateToOrientation: (UIInterfaceOrientation)toInterfaceOrientation;
{
    _interfaceOrientation = toInterfaceOrientation;

    [self.willRotate forEachTargetInCallbacksDo:^(id target, SEL selector, NSMutableDictionary *dict) {
        [target performVoidReturnSelector:selector];
    }];
}

- (void) viewControllerDidRotate;
{
    [self.didRotate forEachTargetInCallbacksDo:^(id target, SEL selector, NSMutableDictionary *dict) {
        [target performVoidReturnSelector:selector];
    }];
}

// Adapted from: http://stackoverflow.com/questions/24150359/is-uiscreen-mainscreen-bounds-size-becoming-orientation-dependent-in-ios8
+ (CGSize) screenSize;
{
    CGSize screenSize = [UIScreen mainScreen].bounds.size;
    CGSize rotatedSize;
    
    if ([UIDevice ios7OrEarlier] && [[SMRotation session] isLandscape]) {
        rotatedSize = CGSizeMake(screenSize.height, screenSize.width);
    }
    else {
        rotatedSize = screenSize;
    }
    
    return rotatedSize;
}

+ (CGPoint) screenCenter;
{
    CGSize size = [self screenSize];
    CGPoint center = CGPointMake(size.width/2.0, size.height/2);
    return center;
}

+ (BOOL) isLandscapeFrame: (CGRect) frame;
{
    return [self isLandscapeSize:frame.size];
}

+ (BOOL) isLandscapeSize: (CGSize) size;
{
    if (size.width > size.height) {
        return YES;
    }
    else {
        return NO;
    }
}

+ (UIInterfaceOrientation) orientationOfSize:(CGSize) size;
{
    if ([self isLandscapeSize:size]) {
        return UIInterfaceOrientationLandscapeLeft;
    }
    else {
        return UIInterfaceOrientationPortrait;
    }
}

+ (void) getLandscapeFrame: (CGRect *) landscapeFrame andPortraitFrame: (CGRect *) portraitFrame fromFrame: (CGRect) frame;
{
    (*landscapeFrame).origin = (*portraitFrame).origin = frame.origin;
    
    if ([self isLandscapeFrame:frame]) {
        *landscapeFrame = frame;
        (*portraitFrame).size.height = frame.size.width;
        (*portraitFrame).size.width = frame.size.height;
    }
    else {
        *portraitFrame = frame;
        (*landscapeFrame).size.height = frame.size.width;
        (*landscapeFrame).size.width = frame.size.height;
    }
}

// This didn't do what I wanted:
// Provides a rotation dependent view that spans the entire screen, independent of iOS version. I was running into problems with iOS7 (and iOS6?) not having the [UIApplication sharedApplication].delegate.window rotated when in landscape mode. I.e., it had 768x1024 (bounds and frame) in landscape.
/*
- (UIView *) window;
{
    UIView *window = [UIApplication sharedApplication].delegate.window;
    
    // See http://stackoverflow.com/questions/2508630/orientation-in-a-uiview-added-to-a-uiwindow
    if ([UIDevice ios7OrEarlier]) {
        window = [[UIApplication sharedApplication].windows objectAtIndex:0];
    }
    
    SPASLogDetail(@"bounds: %@", NSStringFromCGRect(window.bounds));
    SPASLogDetail(@"transform: %@", NSStringFromCGAffineTransform(window.transform));
    
    return window;
}*/

// Adapted from http://stackoverflow.com/questions/2659400/automatically-sizing-uiview-after-adding-to-window
- (void) transformViewAccordingToOrientation: (UIView *) view;
{
    CGAffineTransform rotate = CGAffineTransformMakeRotation([self angleOfOrientation]);
    view.transform = CGAffineTransformConcat(rotate, view.transform);
}

- (CGFloat) angleOfOrientation;
{
    CGFloat angle;
    
    if ([UIDevice iOS8OrLater]) {
        // Because of
        // + (UIInterfaceOrientation) orientationOfSize:(CGSize) size;
        BadMojo("Only use this for iOS7 and earlier");
    }
    
    switch (self.interfaceOrientation)
    {
        case UIInterfaceOrientationPortraitUpsideDown:
            angle = M_PI;
            break;
        case UIInterfaceOrientationLandscapeLeft:
            angle = -M_PI_2;
            break;
        case UIInterfaceOrientationLandscapeRight:
            angle = M_PI_2;
            break;
        default:
            angle = 0.0;
            break;
    }
    
    return angle;
}

- (BOOL) isLandscape;
{
    return !self.isPortrait;
}

- (BOOL) isPortrait;
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

- (BOOL) isInverted;
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

- (void) pushOrientationMask: (NSUInteger) newOrientationMask;
{
    [self.orientationMaskStack addObject:@(newOrientationMask)];
    self.currentOrientationMask = newOrientationMask;
}

- (void) popOrientationMask;
{
    if ([self.orientationMaskStack count]) {
        [self.orientationMaskStack removeLastObject];
    }
    
    UIInterfaceOrientationMask newOrientationMask = self.defaultOrientationMask;
    if ([self.orientationMaskStack count]) {
        newOrientationMask = [[self.orientationMaskStack lastObject] integerValue];
    }
    
    self.currentOrientationMask = newOrientationMask;
}

@end
