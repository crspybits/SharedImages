//
//  Defaults.h
//  Petunia
//
//  Created by Christopher Prince on 12/11/14.
//  Copyright (c) 2014 Spastic Muffin, LLC. All rights reserved.
//

// A simpler notation for NSUserDefaults data.

#import <Foundation/Foundation.h>

@interface Defaults : NSObject

+ (instancetype) session;

// Override the items method in a subclass for your projects in order to define the types and keys for your NSUserDefault values.
// Keys are the nsUserDefaultsKey's
// Values are arrays with the following indices:
#define DEFAULT_INDEX_TYPE 0 // DefaultsType value as an NSNumber
#define DEFAULT_INDEX_DEFAULT 1 // Value returned if Defaults value is nil. Use NSNull for nil.
typedef NS_ENUM(NSUInteger, DefaultsType) {
    DefaultsTypePrimitiveObject, // e.g., NSNumber, NSString (property lists)
    DefaultsTypeArchivableObject, // A custom class that implements NSCoding
    // Perhaps put iCloud here too?
};

- (NSDictionary *) items; // called just once on first usage of this class.

// Reset all of the defaults.
- (void) reset;

// Reset just one to its value in items.
- (void) resetValueFor: (NSString *) nsUserDefaultsKey;

// Returns nil for default values given as NSNull.
+ (id) getValueFor: (NSString *) nsUserDefaultsKey;

// Use a value of nil to reset back to default value.
+ (void) setValue: (id) value for: (NSString *) nsUserDefaultsKey;
+ (void) setValue: (id) value forDefKey: (NSString *) nsUserDefaultsKey; // for Swift; it has a problem with "for:"

@end
