//
//  UIScrollView+Extras.m
//  Petunia
//
//  Created by Christopher Prince on 11/11/14.
//  Copyright (c) 2014 Spastic Muffin, LLC. All rights reserved.
//

#import "UIScrollView+Extras.h"
#import "UIView+Extras.h"
#import "SPASLog.h"

@implementation UIScrollView (Extras)

- (void) setContentOffsetNoDelegate:(CGPoint)contentOffset;
{
    // See http://stackoverflow.com/questions/9418311/setting-contentoffset-programmatically-triggers-scrollviewdidscroll
    /* I've found that this doesn't work in all conditions.
    CGRect scrollBounds = self.bounds;
    scrollBounds.origin = contentOffset;
    self.bounds = scrollBounds;
    */
    
    id<UIScrollViewDelegate> scrollViewDelegate = self.delegate;
    self.delegate = nil;
    self.contentOffset = contentOffset;
    self.delegate = scrollViewDelegate;
}

- (void) relax;
{
    [self relaxGivenContentSize:self.contentSize andAnimationDuration:@(SM_SCROLLVIEW_RELAX_ANIMATION_DURATION_S)];
}

- (void) relaxGivenContentSize: (CGSize) contentSize;
{
    [self relaxGivenContentSize:contentSize andAnimationDuration:@(SM_SCROLLVIEW_RELAX_ANIMATION_DURATION_S)];
}

- (void) relaxGivenAnimationDuration: (NSNumber *) animationDuration;
{
    [self relaxGivenContentSize:self.contentSize andAnimationDuration:animationDuration];
}

- (void) relaxGivenContentSize: (CGSize) contentSize andAnimationDuration: (NSNumber *) animationDuration;
{
    CGPoint relaxedContentOffset = CGPointZero;
    BOOL relaxed = YES;
    CGFloat relaxedOffsetHeight = contentSize.height - self.frameHeight;
    if (relaxedOffsetHeight < 0) {
        // if relaxedOffsetHeight < 0, this means that the frameHeight was greater than the contentSize.height. In that case, our relaxed scroll view should have a content offset of 0.
        relaxedOffsetHeight = 0;
    }
    
    if (self.contentOffset.y < 0) {
        relaxed = NO;
        relaxedContentOffset = CGPointZero;
    }
    else if (self.contentOffset.y > relaxedOffsetHeight) {
        relaxed = NO;
        relaxedContentOffset.y = relaxedOffsetHeight;
    }
    
    if (relaxed) {
        SPASLog(@"Scroll view is 'relaxed'");
    }
    else {
        SPASLog(@"*** Scroll view is NOT 'relaxed' ***");
        [UIView animateWithDurationSync0:animationDuration animations:^{
            [self setContentOffsetNoDelegate:relaxedContentOffset];
        } completion:^(BOOL finished) {
        }];
    }
}


@end
