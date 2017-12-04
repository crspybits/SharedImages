//
//  SMEmail.m
//  Petunia
//
//  Created by Christopher Prince on 9/30/13.
//  Copyright (c) 2013 Spastic Muffin, LLC. All rights reserved.
//

#import "SMEmail.h"
#import "SMUIMessages.h"
#import "UserMessage.h"
#import "UIDevice+Extras.h"

@interface SMEmail ()<MFMailComposeViewControllerDelegate>
@property (nonatomic, weak) UIViewController *myParent;
@end

@implementation SMEmail

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (id) initWithParentViewController: (UIViewController *) theParent {
    if(! [MFMailComposeViewController canSendMail]) {
        NSString *title = [[NSString alloc] initWithFormat:@"Sorry, the %@ app isn't allowed to send email.", [SMUIMessages session].appName];
        UIAlertView *emailAlert =
        [[UIAlertView alloc]
         initWithTitle: title message: @"Have you configured this device to send email?" delegate:nil
         cancelButtonTitle:[[SMUIMessages session] OkMsg]
         otherButtonTitles: nil];
        [[UserMessage session] showAlert:emailAlert ofType:UserMessageTypeError];
        return nil;
    }
    
    self = [super init];
    if (self) {
        self.mailComposeDelegate = self;
        self.myParent = theParent;
    }
    
    return self;
}

- (void) show {
    [self.myParent presentViewController:self animated:YES completion:nil];
}

- (void)mailComposeController:(MFMailComposeViewController*)controller didFinishWithResult:(MFMailComposeResult)result error:(NSError*)error {
    [self.myParent dismissViewControllerAnimated:YES completion:nil];
}

+ (NSString *) getVersionDetailsFor: (NSString *) appName;
{
    NSMutableString *message = [NSMutableString string];
    [message appendString:@"\n\n\n--------------\n"];
    [message appendFormat:@"iOS version: %@\n", [[UIDevice currentDevice] systemVersion]];
    [message appendFormat:@"%@ version: %@ (%@)\n", appName,
     [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"],
     [[NSBundle mainBundle]objectForInfoDictionaryKey:@"CFBundleVersion"]];
    [message appendFormat:@"Hardware: %@\n", [UIDevice machineName]];
    
    return message;
}

@end
