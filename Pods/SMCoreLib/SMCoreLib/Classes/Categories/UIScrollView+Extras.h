//
//  UIScrollView+Extras.h
//  Petunia
//
//  Created by Christopher Prince on 11/11/14.
//  Copyright (c) 2014 Spastic Muffin, LLC. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface UIScrollView (Extras)

// Normally, setting the content offset causes scroll view delegate method(s) to be called. This doesn't. You can animate this.
- (void) setContentOffsetNoDelegate:(CGPoint)contentOffset;

// If needed, animate the scroll view to a content offset where it won't "jump" if you touch it. The relax methods without an animation duration parameter have the following default animulation duration:
#define SM_SCROLLVIEW_RELAX_ANIMATION_DURATION_S 0.3
- (void) relax;
- (void) relaxGivenContentSize: (CGSize) contentSize;

// Give the animation duration as nil if it should be zero.
- (void) relaxGivenAnimationDuration: (NSNumber *) animationDuration;
- (void) relaxGivenContentSize: (CGSize) contentSize andAnimationDuration: (NSNumber *) animationDuration;

@end
