//
//  SMIdentifiers.h
//  SMCommon
//
//  Created by Christopher Prince on 10/3/15.
//  Copyright © 2015 Spastic Muffin, LLC. All rights reserved.
//

// Singleton class

#import <Foundation/Foundation.h>

@interface SMIdentifiers2 : NSObject

+ (instancetype) session;

- (NSString *) bundleIdentifier;

@end
