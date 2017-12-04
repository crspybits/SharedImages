//
//  UINavigationController+Extras.h
//  Petunia
//
//  Created by Christopher Prince on 6/26/15.
//  Copyright (c) 2015 Spastic Muffin, LLC. All rights reserved.
//

// See http://stackoverflow.com/questions/3372333/ipad-keyboard-will-not-dismiss-if-modal-viewcontroller-presentation-style-is-uim

#import <UIKit/UIKit.h>

@interface UINavigationController (Extras)

- (BOOL)disablesAutomaticKeyboardDismissal;

@end
