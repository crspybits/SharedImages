//
//  UINavigationBar+Extras.m
//  Petunia
//
//  Created by Christopher Prince on 11/1/14.
//  Copyright (c) 2014 Spastic Muffin, LLC. All rights reserved.
//

#import "UINavigationBar+Extras.h"

@implementation UINavigationBar (Extras)

+ (CGFloat) defaultHeight;
{
    static UINavigationController *navController = nil;
    if (!navController) {
        navController = [[UINavigationController alloc] init];
    }
    return navController.navigationBar.frame.size.height;
}

@end
