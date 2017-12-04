//
//  Keychain.m
//  Petunia
//
//  Created by Christopher Prince on 10/26/13.
//  Copyright (c) 2013 Spastic Muffin, LLC. All rights reserved.
//

#import "KeyChain.h"
#import <Security/Security.h>
#import "SPASLog.h"
#import "SMAssert.h"
#import "SMIdentifiers2.h"

// [1]. Calling Swift code from KeyChain DOES NOT WORK, seemingly because the KeyChain class is exposed in SMCommon.h. See: http://stackoverflow.com/questions/32919285/ios-framework-with-swift-and-objective-c-where-the-objective-c-uses-swift-c

/* [1].
// You must change the Objective-C Generated Interface Header Name to: App-Swift.h
#ifdef SMCOMMONLIB
#import <SMCommon/App-Swift.h>
#else
#import "App-Swift.h"
#endif
*/

//#define KEYCHAIN_DOMAIN [SMIdentifiers session].APP_BUNDLE_IDENTIFIER
#define KEYCHAIN_DOMAIN [SMIdentifiers2 session].bundleIdentifier

@implementation KeyChain

/*
+ (NSString *) bundleIdentifier;
{
    // 10/3/15. This is redundant with SMIdentifiers.appBundleIdentifier, but I had a whole lot of difficulty (see [1] above), trying to use SMIdentifiers.swift from within here.
    return [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleIdentifier"];
}*/

// See http://stackoverflow.com/questions/11614047/what-makes-a-keychain-item-unique-in-ios
// for the use of kSecClass constants "For a keychain item of class kSecClassGenericPassword, the primary key is the combination of kSecAttrAccount and kSecAttrService."

// Much of this code is from Google Drive

+ (NSString *)secureStringForService:(NSString *)service account:(NSString *)account {
    NSData *tokenData = [KeyChain secureDataForService:service account:account];
    if (! tokenData) return nil;
    return [[NSString alloc] initWithData:tokenData
                                   encoding:NSUTF8StringEncoding];
}

+ (BOOL)removeSecureTokenForService:(NSString *)service account:(NSString *)account {
    if (0 < [service length] && 0 < [account length]) {
        NSMutableDictionary *keychainQuery = [KeyChain keychainQueryForService:service account:account];
        OSStatus status = SecItemDelete((__bridge CFDictionaryRef)keychainQuery);
        if (status != noErr) return NO;
    }

    return YES;
}

+ (BOOL)setSecureString:(NSString *)tokenToSecure
         forService:(NSString *)service
            account:(NSString *)account {
    
    NSData *tokenData = [tokenToSecure dataUsingEncoding:NSUTF8StringEncoding];
    return [KeyChain setSecureData:tokenData forService:service account:account];
}

+ (NSData *)secureDataForService:(NSString *)service account:(NSString *)account {
    NSData *result = nil;
    
    if (0 < [service length] && 0 < [account length]) {
        CFDataRef passwordData = NULL;
        NSMutableDictionary *keychainQuery = [KeyChain keychainQueryForService:service account:account];
        [keychainQuery setObject:(id)kCFBooleanTrue forKey:(__bridge id)kSecReturnData];
        [keychainQuery setObject:(__bridge id)kSecMatchLimitOne forKey:(__bridge id)kSecMatchLimit];
        
        OSStatus status = SecItemCopyMatching((__bridge CFDictionaryRef)keychainQuery,
                                              (CFTypeRef *)&passwordData);
        if (status == noErr && 0 < [(__bridge NSData *)passwordData length]) {
            result = (__bridge_transfer NSData *)passwordData;
        } else {
            if (passwordData != NULL) {
                CFRelease(passwordData);
            }
        }
    }
    
    return result;
}

+ (BOOL)setSecureData:(NSData *)tokenToSecure
           forService:(NSString *)service
              account:(NSString *)account {
    
    // 12/21/15; Due to bug #P151 and #P96 (search for these in the code), I'm trying a workaround. My initial thought for a workaround was to first do a removeSecureTokenForService. The rationale for this workaround comes from the observation that (see bug #P151 writeup) I (often) can reproduce this issue by deleting the app without removing credentials first. Removing the credentials does a removeSecureTokenForService for the expiry dates, the place where I'm running into this issue. This error does not appear to occur if I clear credentials, and remove the app, then reinstall. HOWEVER, the operation of setSecureData always did this-- it always called removeSecureTokenForService first. SO, instead, I'm going to try setting the token to nil if I get an initial failure.
    
    BOOL result = [self setSecureDataAux:tokenToSecure forService:service account:account removeFirst:YES];
    if (result) return YES;
    
    [self setSecureDataAux:nil forService:service account:account removeFirst:NO];
    
    return [self setSecureDataAux:tokenToSecure forService:service account:account removeFirst:NO];
}

+ (BOOL)setSecureDataAux:(NSData *)tokenToSecure
           forService:(NSString *)service
              account:(NSString *)account removeFirst:(BOOL) removeFirst {
    if (0 < [service length] && 0 < [account length]) {
        if (removeFirst && ![KeyChain removeSecureTokenForService:service account:account]) {
            // This is not really a problem; just being verbose.
            SPASLog(@"KeyChain.setSecureData: Could not remove previous token (service: %@, account: %@)", service, account);
        }
        
        if (0 < [tokenToSecure length]) {
            NSMutableDictionary *keychainQuery = [KeyChain keychainQueryForService:service account:account];

            [keychainQuery setObject:tokenToSecure forKey:(__bridge id)kSecValueData];
            
            // For possible values for kSecAttrAccessible: https://developer.apple.com/library/ios/documentation/Security/Reference/keychainservices/Reference/reference.html#//apple_ref/doc/constant_group/Keychain_Item_Accessibility_Constants
            
            [keychainQuery setObject:(__bridge id)kSecAttrAccessibleWhenUnlockedThisDeviceOnly
                              forKey:(__bridge id)kSecAttrAccessible];
            OSStatus status = SecItemAdd((__bridge CFDictionaryRef)keychainQuery, NULL);
            
            AssertIf(nil == KEYCHAIN_DOMAIN, @"No KEYCHAIN_DOMAIN");
            
            if (status != noErr) {
                NSError *error = [NSError errorWithDomain:KEYCHAIN_DOMAIN
                                                     code:status
                                                 userInfo:nil];
                SPASLogFile(@"KeyChain.setSecureData: Service: %@, Account: %@, Error: %@", service, account, error);
                return NO;
            }
        }
    }
    
    return YES;
}

#define GENERIC_ATTRIBUTE KEYCHAIN_DOMAIN

+ (NSMutableDictionary *)keychainQueryForService:(NSString *)service account:(NSString *)account {
    NSMutableDictionary *query = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                                  (__bridge id)kSecClassGenericPassword, (__bridge id)kSecClass,
                                  GENERIC_ATTRIBUTE, (__bridge id)kSecAttrGeneric,
                                  account, (__bridge id)kSecAttrAccount,
                                  service, (__bridge id)kSecAttrService,
                                  nil];
    return query;
}

/*
 NSData *data = [KeyChain secureDataForService:productId account:ACCOUNT_EXPIRY];
 if (!data) return nil;
 
 id date = [NSKeyedUnarchiver unarchiveObjectWithData:data];
 if (! date) return nil;
 */
+ (NSDate *)secureDateForService:(NSString *)service account:(NSString *)account {
    NSData *data = [KeyChain secureDataForService:service account:account];
    if (!data) return nil;
    
    id date = [NSKeyedUnarchiver unarchiveObjectWithData:data];
    return date;
}

+ (BOOL)setSecureDate:(NSDate *)dateToSecure
           forService:(NSString *)service
              account:(NSString *)account {
    NSData *archivedData = [NSKeyedArchiver archivedDataWithRootObject:dateToSecure];
    if (! archivedData) {
        SPASLogFile(@"Could not archive data for: %@", dateToSecure);
        return NO;
    }
    return [KeyChain setSecureData:archivedData forService:service account:account];
}

@end


