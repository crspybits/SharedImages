//
//  SMAppearance.m
//  Petunia
//
//  Created by Christopher Prince on 4/25/15.
//  Copyright (c) 2015 Spastic Muffin, LLC. All rights reserved.
//

#import "SMAppearance.h"
#import "UIDevice+Extras.h"

@interface SMAppearance()
@property (nonatomic) CGFloat navBarHeight;
@property (nonatomic) CGFloat statusBarHeight;
@end

#define STATUS_BAR_HEIGHT 20

@implementation SMAppearance

+ (instancetype) session;
{
    static SMAppearance* s_sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        s_sharedInstance = [self new];
        
        UINavigationController *navController = [[UINavigationController alloc] init];
        s_sharedInstance.navBarHeight = navController.navigationBar.frame.size.height;
        
        s_sharedInstance.statusBarHeight = STATUS_BAR_HEIGHT;
    });
    
    return s_sharedInstance;
}

- (void) roundCornersOnModalWithView: (UIView *) view;
{
    // 9/23/14; I don't know why, but for some reason, I'm not getting rounded corners on the Data Entry VC now. Odd. It seems to have come along with the change for iOS to use the transitioning delegate, but it even happens on iOS7. With a prior release candidate... I care about this only because (1) the help images I've created have the rounded corners, and (2) some other VC's (the store VC controller) have rounded corners.
    // Note that this doesn't work when  when placed in showWithCompletion. And I think it also wasn't working in viewWillAppear.
    
    // Why does this work? I'm not 100% sure. Better programming through hacking!
    // See also http://expertsoverflow.com/questions/20609717/rounding-corners-of-uimodalpresentationformsheet
    // And http://stackoverflow.com/questions/20609717/rounding-corners-of-uimodalpresentationformsheet
    CALayer *layer;
    if ([UIDevice iOS8OrLater]) {
        layer = view.layer;
    } else {
        layer = view.superview.layer;
    }
    
    // This value for cornerRadius matches up well with it was before something changed to remove the corner rounding.
    layer.cornerRadius  = 5.0;
    layer.masksToBounds = YES;
}

- (CGFloat) toolBarHeight;
{
    return self.navBarHeight;
}



@end
