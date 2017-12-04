//
//  SMUIMessages.h
//  Catsy
//
//  Created by Christopher Prince on 6/13/15.
//  Copyright (c) 2015 Spastic Muffin, LLC. All rights reserved.
//

// This is to support standard message text, and to also help with possible later localization.

#import <Foundation/Foundation.h>

@interface SMUIMessages : NSObject

+ (instancetype) session;

- (NSString *) OkMsg;
- (NSString *) leftNavCloseButtonTitle;

// You need to set this at launch time.
@property (nonatomic, strong) NSString *appName;

@end
