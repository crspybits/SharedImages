//
//  SMMutableDictionary.h
//  Dictionary
//
//  Created by Christopher Prince on 10/6/15.
//  Copyright © 2015 Spastic Muffin, LLC. All rights reserved.
//

/* I subclassed NSMutableDictionary because:
    1) because I needed a way to know when a key was set or removed. With other mutable objects you can use proxy objects (e.g., see https://www.objc.io/issues/7-foundation/key-value-coding-and-observing/), but a proxy object doesn't seem to be provided by Apple for NSMutableDictionary's.
    2) for notational convenience in some other code that I was writing.
*/

// QUESTION: Can I set up an observer to detect any changes to the value of the key's within the dictionary? We'd have to remove this KVO observer if the object was removed. Presumably, with this interface, the way that the object would be removed would be (a) setting with nil, and (b) deallocation of this SMMutableDictionary itself.

// For a discussion of my issues in implementing this, see http://stackoverflow.com/questions/33028236/what-are-the-traps-and-tribulations-when-it-comes-to-subclassing-nsmutabledictio/33028487#33028487

#import <Foundation/Foundation.h>

@class SMMutableDictionary;

@protocol SMMutableDictionaryDelegate <NSObject>

@required

// Reports on the assignment to a keyed value for this dictionary and the removal of a key: setObject:forKey: and removeObjectForKey:
- (void) dictionaryWasChanged: (SMMutableDictionary * _Nonnull) dict;

@end

@interface SMMutableDictionary : NSMutableDictionary

// Needed as we use mutableCopy in SMPersistVars
- (instancetype _Nonnull) mutableCopy;

// For some reason (more of the ugliness associated with having an NSMutableDictionary subclass), when you unarchive a keyed archive of an SMMutableDictionary, it doesn't give you back the SMMutableDictionary, it gives you an NSMutableDictionary. So, these method are for your convenience. AND, almost even better, when you use a keyed archiver to archive, it uses our encoder method, but doesn't actually generate an archive containing our dictionary!! SO, don't use keyed archiver methods directly, use the following two methods:
- (NSData * _Nullable) archive;
+ (instancetype _Nullable) unarchiveFromData: (NSData * _Nonnull) keyedArchiverData;

// Optional delegate
@property (nonatomic, weak, nullable) id<SMMutableDictionaryDelegate> delegate;

@end
