//
//  UIView+Extras.m
//  Petunia
//
//  Created by Christopher Prince on 9/18/13.
//  Copyright (c) 2013 Spastic Muffin, LLC. All rights reserved.
//

// V3

#import "UIView+Extras.h"
#import <QuartzCore/QuartzCore.h>
#import "SPASLog.h"
#import "SMAssert.h"

@implementation UIView (Extras)

- (void) setFrameOrigin: (CGPoint) origin {
    CGRect frame = self.frame;
    frame.origin = origin;
    self.frame = frame;
}

- (void) setFrameX: (CGFloat) x {
    CGRect frame = self.frame;
    frame.origin.x = x;
    self.frame = frame;
}

- (void) setFrameY: (CGFloat) y;
{
    CGRect frame = self.frame;
    frame.origin.y = y;
    self.frame = frame;
}

- (void) setFrameHeight:(CGFloat)height
{
    CGRect frame = self.frame;
    frame.size.height = height;
    self.frame = frame;
}

- (void) setFrameWidth:(CGFloat)width
{
    CGRect frame = self.frame;
    frame.size.width = width;
    self.frame = frame;
}

- (void) setFrameSize: (CGSize) size
{
    CGRect frame = self.frame;
    frame.size = size;
    self.frame = frame;
}

- (CGFloat) frameX
{
    return self.frame.origin.x;
}

- (CGFloat) frameY
{
    return self.frame.origin.y;
}

- (CGFloat) frameWidth
{
    return self.frame.size.width;
}

- (CGFloat) frameHeight
{
    return self.frame.size.height;
}

- (CGPoint) frameOrigin
{
    return self.frame.origin;
}

- (CGSize) frameSize
{
    return self.frame.size;
}

- (CGFloat) boundsX
{
    return self.bounds.origin.x;
}

- (CGFloat) boundsY
{
    return self.bounds.origin.y;
}

- (CGFloat) boundsWidth
{
    return self.bounds.size.width;
}

- (CGFloat) boundsHeight
{
    return self.bounds.size.height;
}

- (CGPoint) boundsOrigin
{
    return self.bounds.origin;
}

- (CGSize) boundsSize
{
    return self.bounds.size;
}

- (void) setBoundsOrigin: (CGPoint) origin {
    CGRect frame = self.bounds;
    frame.origin = origin;
    self.bounds = frame;
}

- (void) setBoundsSize: (CGSize) size
{
    CGRect frame = self.bounds;
    frame.size = size;
    self.bounds = frame;
}

- (void) setBoundsHeight: (CGFloat) height;
{
    CGRect bounds = self.bounds;
    bounds.size.height = height;
    self.bounds = bounds;
}

- (void) setBoundsWidth: (CGFloat) width;
{
    CGRect bounds = self.bounds;
    bounds.size.height = width;
    self.bounds = bounds;
}

- (void) setBoundsX: (CGFloat) x;
{
    CGRect bounds = self.bounds;
    bounds.origin.x = x;
    self.bounds = bounds;
}

- (void) setBoundsY: (CGFloat) y;
{
    CGRect bounds = self.bounds;
    bounds.origin.y = y;
    self.bounds = bounds;
}

- (CGFloat) boundsMaxX;
{
    return (self.bounds.origin.x + self.bounds.size.width);
}

- (void)setBoundsMaxX:(CGFloat)boundsMaxX;
{
    CGRect bounds = self.bounds;
    bounds.origin.x = boundsMaxX - self.bounds.size.width;
    self.bounds = bounds;
}

- (CGFloat) boundsMaxY;
{
    return (self.bounds.origin.y + self.bounds.size.height);
}

- (void) setBoundsMaxY:(CGFloat)boundsMaxY;
{
    CGRect bounds = self.bounds;
    bounds.origin.y = boundsMaxY - self.bounds.size.height;
    self.bounds = bounds;
}

- (void) centerVerticallyInSuperview;
{
    if (! self.superview) return;
    
    SPASLog(@"self.superview.height: %f", self.superview.frameHeight);
    CGFloat superCenterY = self.superview.frameHeight/2.0;
    CGPoint selfCenter = self.center;
    selfCenter.y = superCenterY;
    self.center = selfCenter;
}

- (void) centerHorizontallyInSuperview;
{
    if (! self.superview) return;
    
    //SPASLog(@"self.superview.height: %f", self.superview.frameHeight);
    CGFloat superCenterX = self.superview.frameWidth/2.0;
    CGPoint selfCenter = self.center;
    selfCenter.x = superCenterX;
    self.center = selfCenter;
}

- (void) centerInSuperview;
{
    [self centerVerticallyInSuperview];
    [self centerHorizontallyInSuperview];
}

- (void) centerVerticallyInSuperviewBounds;
{
    if (! self.superview) return;
    
    SPASLog(@"self.superview.height: %f", self.superview.boundsHeight);
    CGFloat superCenterY = self.superview.boundsHeight/2.0;
    CGPoint selfCenter = self.center;
    selfCenter.y = superCenterY;
    self.center = selfCenter;
}

- (void) centerHorizontallyInSuperviewBounds;
{
    if (! self.superview) return;
    
    //SPASLog(@"self.superview.height: %f", self.superview.frameHeight);
    CGFloat superCenterX = self.superview.boundsWidth/2.0;
    CGPoint selfCenter = self.center;
    selfCenter.x = superCenterX;
    self.center = selfCenter;
}

- (void) centerInSuperviewBounds;
{
    [self centerVerticallyInSuperviewBounds];
    [self centerHorizontallyInSuperviewBounds];
}

+ (void) distributeViewsHorizontally: (NSArray *) views;
{
    AssertIf([views count] == 0, @"Must have more than 0 views!");
    UIView *firstView = views[0];
    CGFloat superViewWidth = firstView.superview.frameWidth;
    CGFloat totalWidthOfViews = 0.0;
    
    for (UIView *view in views) {
        totalWidthOfViews += view.frameWidth;
    }
    
    AssertIf(superViewWidth < totalWidthOfViews, @"Subviews wider (=%f) than superview (=%f)!", totalWidthOfViews, superViewWidth);
    CGFloat spacingBetween = (superViewWidth - totalWidthOfViews)/([views count] + 1);
    
    CGFloat currentX = spacingBetween;
    for (UIView *view in views) {
        view.frameX = currentX;
        currentX += view.frameWidth + spacingBetween;
    }
}

+ (void) distributeViewsVertically: (NSArray *) views;
{
    AssertIf([views count] == 0, @"Must have more than 0 views!");
    UIView *firstView = views[0];
    CGFloat superViewHeight = firstView.superview.frameHeight;
    CGFloat totalHeightOfViews = 0.0;
    
    for (UIView *view in views) {
        totalHeightOfViews += view.frameHeight;
    }
    
    AssertIf(superViewHeight < totalHeightOfViews, @"Subviews taller (=%f) than superview (=%f)!", totalHeightOfViews, superViewHeight);
    CGFloat spacingBetween = (superViewHeight - totalHeightOfViews)/([views count] + 1);
    
    CGFloat currentY = spacingBetween;
    for (UIView *view in views) {
        view.frameY = currentY;
        currentY += view.frameHeight + spacingBetween;
    }
}

+ (void) distributeViewsExactlyVertically: (NSArray *) views;
{
    AssertIf([views count] == 0, @"Must have more than 0 views!");
    UIView *firstView = views[0];
    
    CGFloat totalHeightOfViews = 0.0;
    
    for (UIView *view in views) {
        totalHeightOfViews += view.frameHeight;
    }
    
    firstView.superview.frameHeight = totalHeightOfViews;
    
    [self distributeViewsVertically:views];
}

+ (void) performAnimationSequence: (NSArray *) animations andThenCompletion: (AnimationDone) completion {
    SPASLog(@"UIView+Extras.performAnimationSequence: Starting: %@", [NSDate date]);
    [self performAnimation: 0 fromSequence:animations andThenCompletion:completion];
}

+ (void) performAnimation: (NSUInteger) current fromSequence: (NSArray *) animations andThenCompletion: (AnimationDone) completion {
    
    // Base case of recursion
    if (current == [animations count]) {
        SPASLog(@"UIView+Extras.performAnimationSequence: Ending: %@", [NSDate date]);
        if (completion) completion();
        return;
    }
    
    [CATransaction begin];
    
    [CATransaction setCompletionBlock:^{
        // This block runs *after* any animations created before the call to
        // [CATransaction commit] below.
        
        // Next step in recursion
        [self performAnimation: current+1 fromSequence:animations andThenCompletion:completion];
    }];
    
    AnimationStep currentAnimation = animations[current];
    currentAnimation();
    
    [CATransaction commit];
}

// It doesn't seem good to use the same name as in UIView: see http://stackoverflow.com/questions/5272451/overriding-methods-using-categories-in-objective-c
+ (void)animateWithDurationSync0:(NSNumber *)duration animations:(void (^)(void))animations completion:(void (^)(BOOL finished))completion;
{
    SPASLog(@"UIView+Extras.animateWithDurationSync0");
    if (nil == duration) {
        animations();
        if (completion) completion(YES);
    } else {
        [UIView animateWithDuration:[duration floatValue] animations:animations completion:completion];
    }
}

+ (void) animateBlock: (void (^)(void)) blockToAnimate;
{
    [UIView animateWithDuration:0.3 delay:0 options:UIViewAnimationOptionCurveEaseIn animations:^{
        AssertIf(nil == blockToAnimate, @"Cannot have nil block");
        blockToAnimate();
    } completion:^(BOOL finished) {
    }];
}

- (void) setDebugBlackBorder:(BOOL)blackBorder
{
    CALayer *layer = self.layer;
    if (blackBorder) {
        layer.borderColor = [UIColor blackColor].CGColor;
        layer.borderWidth = 1.0;
    } else {
        layer.borderWidth = 0.0;
    }
}

- (void) setDebugBorderColor:(UIColor *) color;
{
    CALayer *layer = self.layer;
    if (color) {
        layer.borderColor = color.CGColor;
        layer.borderWidth = 1.0;
    } else {
        layer.borderWidth = 0.0;
    }
}

- (BOOL) debugBlackBorder
{
    CALayer *layer = self.layer;
    return (layer.borderWidth == 1.0);
}

- (UIColor *) debugBorderColor;
{
    CALayer *layer = self.layer;
    return [[UIColor alloc] initWithCGColor:layer.borderColor];
}

- (CGFloat) frameMaxX;
{ return (self.frame.origin.x + self.frame.size.width); }

- (void)setFrameMaxX:(CGFloat)frameMaxX;
{
    CGRect frame = self.frame;
    frame.origin.x = frameMaxX - self.frame.size.width;
    self.frame = frame;
}

- (CGFloat) frameMaxY;
{ return (self.frame.origin.y + self.frame.size.height); }

- (void) setFrameMaxY:(CGFloat)frameMaxY;
{
    CGRect frame = self.frame;
    frame.origin.y = frameMaxY - self.frame.size.height;
    self.frame = frame;
}

- (void) removeAllSubviews;
{
    for (UIView *view in self.subviews) {
        [view removeFromSuperview];
    }
}

- (CGFloat) centerX;
{
    return self.center.x;
}

- (CGFloat) centerY;
{
    return self.center.y;
}

- (void) setCenterX:(CGFloat)x;
{
    CGPoint center = self.center;
    center.x = x;
    self.center = center;
}

- (void) setCenterY:(CGFloat)y;
{
    CGPoint center = self.center;
    center.y = y;
    self.center = center;
}

- (void) setEditingBorder:(BOOL)editingBorder;
{
    CALayer *layer = self.layer;
    if (editingBorder) {
        layer.borderColor = [[UIColor alloc] initWithWhite:0.8 alpha:1.0].CGColor;
        layer.borderWidth = 1.0;
    }
    else {
        layer.borderColor = nil;
        layer.borderWidth = 0.0;
    }
}

- (BOOL) editingBorder;
{
    CALayer *layer = self.layer;
    return layer.borderWidth == 0.0;
}

- (void) constrainToFrame: (UIView *) view;
{
    if (view.frameX < 0.0) {
        view.frameX = 0.0;
    }
    else if (view.frameX+view.frameWidth > self.frameWidth) {
        view.frameX = self.frameWidth - view.frameWidth;
    }
    
    if (view.frameY < 0.0) {
        view.frameY = 0.0;
    }
    else if (view.frameY+view.frameHeight > self.frameHeight) {
        view.frameY = self.frameHeight - view.frameHeight;
    }
}

@end
