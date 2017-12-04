//
//  Keychain.h
//  Petunia
//
//  Created by Christopher Prince on 10/26/13.
//  Copyright (c) 2013 Spastic Muffin, LLC. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface KeyChain : NSObject

// Examples of service: "uid", "password", "username"
// Example of account: "PetuniaServer"

+ (NSString *)secureStringForService:(NSString *)service account:(NSString *)account;
+ (BOOL)setSecureString:(NSString *)tokenToSecure
            forService:(NSString *)service
               account:(NSString *)account;

+ (NSDate *)secureDateForService:(NSString *)service account:(NSString *)account;
+ (BOOL)setSecureDate:(NSDate *)dateToSecure
           forService:(NSString *)service
              account:(NSString *)account;

+ (BOOL)removeSecureTokenForService:(NSString *)service account:(NSString *)account;

+ (NSData *)secureDataForService:(NSString *)service account:(NSString *)account;
+ (BOOL)setSecureData:(NSData *)tokenToSecure
             forService:(NSString *)service
                account:(NSString *)account;

@end
