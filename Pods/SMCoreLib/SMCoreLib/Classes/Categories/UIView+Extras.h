//
//  UIView+Extras.h
//  Petunia
//
//  Created by Christopher Prince on 9/18/13.
//  Copyright (c) 2013 Spastic Muffin, LLC. All rights reserved.
//

// V3

#import <UIKit/UIKit.h>

typedef void (^AnimationStep)(void);
typedef void (^AnimationDone)(void);

@interface UIView (Extras)

// Animations must be an array of Blocks of type AnimationStep.
// 1/13/15. I don't think this works with all cases of iOS animations. See note [1] in CoreDataTableViewController.m.
// See also http://stackoverflow.com/questions/7196197/catransaction-synchronize-called-within-transaction/10309729#10309729
+ (void) performAnimationSequence: (NSArray *) animations andThenCompletion: (AnimationDone) completion;

// The need for this method is a little convoluted. It doesn't seem possible to call animateWithDuration within a loop *even if* the duration is 0. That is, there appears to be some latency (asynchrony) between the animations block and the completion block if duration is 0. So, this special version has no latency/asynchrony between the animations block and the completion block if duration is nil.
+ (void)animateWithDurationSync0:(NSNumber *)duration animations:(void (^)(void))animations completion:(void (^)(BOOL finished))completion;

// Put your animations, e.g., frame changes, in a block.
+ (void) animateBlock: (void (^)(void)) blockToAnimate;

/*
- (void) setFrameSize: (CGSize) size;
- (void) setFrameOrigin: (CGPoint) origin;
- (void) setFrameX: (CGFloat) x;
- (void) setFrameY: (CGFloat) y;
- (void) setFrameMaxX: (CGFloat) frameMaxX;
- (void) setFrameMaxY: (CGFloat) frameMaxY;
- (void) setFrameHeight: (CGFloat) height;
- (void) setFrameWidth: (CGFloat) width;

- (void) setCenterX: (CGFloat) x;
- (void) setCenterY: (CGFloat) y;

- (void) setBoundsOrigin: (CGPoint) origin;
- (void) setBoundsSize: (CGSize) size;
- (void) setBoundsHeight: (CGFloat) height;
- (void) setBoundsWidth: (CGFloat) width;
- (void) setBoundsMaxX: (CGFloat) boundsMaxX;
- (void) setBoundsMaxY: (CGFloat) boundsMaxY;
*/

// WRT frame.
- (void) centerVerticallyInSuperview;
- (void) centerHorizontallyInSuperview;
- (void) centerInSuperview;

// WRT to bounds. Use these if the view is transformed.
- (void) centerVerticallyInSuperviewBounds;
- (void) centerHorizontallyInSuperviewBounds;
- (void) centerInSuperviewBounds;

// Assumes views have already been added to superview. Makes white space between the views equal.
+ (void) distributeViewsHorizontally: (NSArray *) views;
+ (void) distributeViewsVertically: (NSArray *) views;

// Same as above, but creates the exact space (no white space between) in the superview.
+ (void) distributeViewsExactlyVertically: (NSArray *) views;

- (void) removeAllSubviews;

// make sure all of the view is contained in the frame of the receiver, and if it is not, adjust it so that it is. Assumes view is a subview of the receiver. Also assumes that the height and width of the view are smaller than the height and width of the receiver.
// Constrain the receivers frame to the view's frame.
- (void) constrainToFrame: (UIView *) view;

@property (nonatomic) CGFloat frameX;
@property (nonatomic) CGFloat frameY;
@property (nonatomic) CGFloat frameMaxX;
@property (nonatomic) CGFloat frameMaxY;
@property (nonatomic) CGFloat frameWidth;
@property (nonatomic) CGFloat frameHeight;
@property (nonatomic) CGPoint frameOrigin;
@property (nonatomic) CGSize frameSize;

@property (nonatomic) CGFloat boundsX;
@property (nonatomic) CGFloat boundsY;
@property (nonatomic) CGFloat boundsMaxX;
@property (nonatomic) CGFloat boundsMaxY;
@property (nonatomic) CGFloat boundsWidth;
@property (nonatomic) CGFloat boundsHeight;
@property (nonatomic) CGPoint boundsOrigin;
@property (nonatomic) CGSize boundsSize;

@property (nonatomic) CGFloat centerX;
@property (nonatomic) CGFloat centerY;

// Standardize on a light gray editing border around fields that are editable. Default is NO.
@property (nonatomic) BOOL editingBorder;

// For debugging
@property (nonatomic) BOOL debugBlackBorder;
@property (nonatomic) UIColor *debugBorderColor;

- (void) setDebugBlackBorder: (BOOL) blackBorder;
- (void) setDebugBorderColor:(UIColor *) color;

@end
