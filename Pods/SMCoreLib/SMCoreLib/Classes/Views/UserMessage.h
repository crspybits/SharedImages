//
//  UserMessage.h
//  Common
//
//  Created by Christopher Prince on 1/8/15.
//  Copyright (c) 2015 Spastic Muffin, LLC. All rights reserved.
//

// Enabling upper level code to provide a more specialized user message (alert) service for lower level code.

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@interface UserMessageDetails : NSObject<UIAlertViewDelegate>

// Set this if you want to dismiss the alert after a specified time, if not dismissed by the user. The default for this is nil, where no timer will be used.
@property (nonatomic, strong) NSNumber *dismissAfterTimeIntervalS;

@property (nonatomic, strong)  NSDictionary *userInfo;

#define ALERT_DELEGATE_DISMISS_WITH_CALLBACK 0
#define ALERT_DELEGATE_DISMISS_WITHOUT_CALLBACK 1

@property (nonatomic, strong) void (^buttonClickHandler)(NSUInteger buttonNumber);
@property (nonatomic, strong) void (^showCompletion)(void);
@property (nonatomic, strong) void (^didDismissHandler)(NSUInteger buttonNumber);

// for active show
@property (nonatomic, strong) void (^beforeShow)(void);
@property (nonatomic, strong) void (^afterShow)(void);

// Shows the alert if application is currently in active state, or waits until it is an active state to show.
- (void) activeShow;

// Dismiss the user message.
- (void) dismiss;

@end

@interface UserMessage : NSObject

+ (instancetype) session;

typedef NS_ENUM(NSInteger, UserMessageType) {
    UserMessageTypeInfo,
    UserMessageTypeError,
};

// It's assumed you don't care about the particular click option selected by the user. This is best used with just an "OK" button alert. Or your own alert delegate can handle button clicks.
- (void) showAlert: (UIAlertView *) alert ofType: (UserMessageType) messageType;

// A short form of the next method. Keep a strong reference to the returned object. Don't change the UserMessageDetails object returned.
- (UserMessageDetails *) showAlert: (UIAlertView *) alert ofType: (UserMessageType) messageType withButtonClickHandler: (void (^)(NSUInteger buttonNumber)) buttonClickHandler;

// Keep a strong reference to the UserMessageDetails object until the alert is fully dismissed.
// The UserMessageDetails will serve as the alert delegate. Don't use your own delegate. You do need to setup the properties of the UserMessageDetails object as you need though.
- (void) showAlert: (UIAlertView *) alert ofType: (UserMessageType) messageType withDetails: (UserMessageDetails *) details;

@property (nonatomic, strong) void (^willShowInfoMessage)(NSDictionary *userInfo);
@property (nonatomic, strong) void (^didShowInfoMessage)(NSDictionary *userInfo);

@property (nonatomic, strong) void (^willShowErrorMessage)(NSDictionary *userInfo);
@property (nonatomic, strong) void (^didShowErrorMessage)(NSDictionary *userInfo);

@end
