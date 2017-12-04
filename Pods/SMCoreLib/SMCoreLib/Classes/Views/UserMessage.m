//
//  UserMessage.m
//  Common
//
//  Created by Christopher Prince on 1/8/15.
//  Copyright (c) 2015 Spastic Muffin, LLC. All rights reserved.
//

#import "UserMessage.h"
#import "BiRef.h"
#import "SPASLog.h"
#import "TimedCallback.h"

@interface UserMessageDetails()<UIAlertViewDelegate>
@property (strong, nonatomic) BiRef *alertRef;

// If we don't use this, we get a double callback.
@property (nonatomic) BOOL called;

@property (nonatomic) BOOL activeShowDone;

@property (nonatomic, strong) TimedCallback *timedCallback;
@end

@implementation UserMessageDetails

- (instancetype) init;
{
    self = [super init];
    if (self) {
        self.alertRef = [BiRef new];
    }
    return self;
}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
    SPASLog(@"Utilities.clickedButtonAtIndex");
    
    if (!self.called && self.buttonClickHandler) {
        [self cancelTimer];
        self.called = YES;
        self.buttonClickHandler(buttonIndex);
    }
}

- (void) alertView:(UIAlertView *)alertView willDismissWithButtonIndex:(NSInteger)buttonIndex {
    if (!self.called && self.buttonClickHandler && ALERT_DELEGATE_DISMISS_WITH_CALLBACK == buttonIndex) {
        [self cancelTimer];
        self.called = YES;
        self.buttonClickHandler(buttonIndex);
    }
}

- (void) alertView:(UIAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex;
{
    if (!self.called && self.didDismissHandler) {
        [self cancelTimer];
        self.called = YES;
        self.didDismissHandler(buttonIndex);
    }
}

- (void) activeShow;
{
    // I'm trying to avoid a possible race condition here where between checking the application state and adding the observer, the application became active.
    self.activeShowDone = NO;
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(becomeActiveNotification:)
                                                 name:UIApplicationDidBecomeActiveNotification object:nil];
    
    UIApplication *app = [UIApplication sharedApplication];
    if (app.applicationState == UIApplicationStateActive) {
        [self finishActiveShow];
        [self removeBecomeActiveObserver];
    }
}

- (void) finishActiveShow;
{
    @synchronized(self) {
        if (!self.activeShowDone) {
            if (self.beforeShow) {
                self.beforeShow();
            }
            UIAlertView *alert = [self.alertRef obj];
            [alert show];
            if (self.afterShow) {
                self.afterShow();
            }
            
            self.activeShowDone = YES;
        }
    }
}

- (void) becomeActiveNotification:(id) sender;
{
    SPASLog(@"UIApplicationDidBecomeActiveNotification: %@", sender);
    // From https://developer.apple.com/library/ios/documentation/Cocoa/Conceptual/Notifications/Articles/NotificationCenters.html
    // "In a multithreaded application, notifications are always delivered in the thread in which the notification was posted, which may not be the same thread in which an observer registered itself."
    // So, it seems that we may not get the notification on the main thread.
    dispatch_async(dispatch_get_main_queue(), ^{
        [self finishActiveShow];
    });
    
    [self removeBecomeActiveObserver];
}

- (void) removeBecomeActiveObserver;
{
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationDidBecomeActiveNotification object:nil];
}

- (void) dismiss;
{
    [self cancelTimer];
    [self.alertRef.obj dismiss];
}

- (void) cancelTimer;
{
    [self.timedCallback cancel];
    self.timedCallback = nil;
}

@end

@implementation UserMessage

+ (instancetype) session;
{
    static UserMessage* s_sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        s_sharedInstance = [self new];
    });
    
    return s_sharedInstance;
}

- (void) showAlert: (UIAlertView *) alert ofType: (UserMessageType) messageType;
{
    [alert show];
}

- (UserMessageDetails *) showAlert: (UIAlertView *) alert ofType: (UserMessageType) messageType withButtonClickHandler: (void (^)(NSUInteger)) buttonClickHandler;
{
    UserMessageDetails *details = [UserMessageDetails new];
    details.buttonClickHandler = buttonClickHandler;
    [self showAlert:alert ofType:messageType withDetails:details];
    return details;
}

- (void) showAlert: (UIAlertView *) alert ofType: (UserMessageType) messageType withDetails: (UserMessageDetails *) details;
{
    details.alertRef.wObj = alert;
    alert.delegate = details;
    
    if (details.dismissAfterTimeIntervalS) {
        // If no one taps on the alert, dismiss it within an interval
        details.timedCallback = [TimedCallback withDuration:[details.dismissAfterTimeIntervalS floatValue] andCallback:^{
            
            [details dismiss];
        }];
    }
    
    [alert show];
}

@end
