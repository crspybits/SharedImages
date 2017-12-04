//
//  SMEmail.h
//  Petunia
//
//  Created by Christopher Prince on 9/30/13.
//  Copyright (c) 2013 Spastic Muffin, LLC. All rights reserved.
//

#import <MessageUI/MessageUI.h>

@interface SMEmail : MFMailComposeViewController

// Returns nil if can't send email on this device. Displays an alert before returning in this case.
- (id) initWithParentViewController: (UIViewController *) parent;

// Show the email composer.
- (void) show;

// Message to append to the bottom of support emails. The string doesn't contain HTML.
+ (NSString *) getVersionDetailsFor: (NSString *) appName;

@end
