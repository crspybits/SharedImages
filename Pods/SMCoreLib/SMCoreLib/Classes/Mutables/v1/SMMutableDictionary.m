//
//  SMMutableDictionary.m
//  Dictionary
//
//  Created by Christopher Prince on 10/6/15.
//  Copyright © 2015 Spastic Muffin, LLC. All rights reserved.
//

// I wanted to make this a Swift NSMutableDictionary subclass, but run into issues...
// See http://stackoverflow.com/questions/28636598/cannot-override-initializer-of-nsdictionary-in-swift
// http://www.cocoawithlove.com/2008/12/ordereddictionary-subclassing-cocoa.html
// See also http://stackoverflow.com/questions/10799444/nsdictionary-method-only-defined-for-abstract-class-my-app-crashed
// I tried only implementing the subscript method for Swift (see https://developer.apple.com/library/ios/documentation/Swift/Conceptual/Swift_Programming_Language/Subscripts.html), but notationally this left much to be desired. I really wanted a type that was fully interoperable with NSDictionary/NSMutableDictionary, which seems to require a subclass.

// See also http://www.smackie.org/notes/2007/07/11/subclassing-nsmutabledictionary/

#import "SMMutableDictionary.h"

@interface SMMutableDictionary()
@property (nonatomic, strong) NSMutableDictionary *dict;
@end

// See this for methods you have to implement to subclass: https://developer.apple.com/library/prerelease/ios/documentation/Cocoa/Reference/Foundation/Classes/NSMutableDictionary_Class/index.html
// HOWEVER, while they didn't say you have to subclass the init method, it did't work for me without doing that. i.e., I needed to have [1] below.

@implementation SMMutableDictionary

- (instancetype) initWithObjects:(const id  _Nonnull __unsafe_unretained *)objects forKeys:(const id<NSCopying>  _Nonnull __unsafe_unretained *)keys count:(NSUInteger)cnt;
{
    self = [super init];
    if (self) {
        self.dict = [[NSMutableDictionary alloc] initWithObjects:objects forKeys:keys count:cnt];
    }
    return self;
}

// [1].
- (instancetype) init;
{
    self = [super init];
    if (self) {
        self.dict = [NSMutableDictionary new];
    }
    return self;
}

// Both of these are useless. See the keyed archiver/unarchiver methods on the .h interface.
/*
- (void)encodeWithCoder:(NSCoder *)aCoder;
{
    //[aCoder encodeObject:self.dict];
    [aCoder encodeObject:self.dict forKey:@"dict"];
}
 */

/*
- (nullable instancetype)initWithCoder:(NSCoder *)aDecoder;
{
    self = [super initWithCoder:aDecoder];
    if (self) {
        //self.dict = [aDecoder decodeObject];
        self.dict = [aDecoder decodeObjectForKey:@"dict"];
    }
    return self;
}
*/

- (NSData * _Nullable) archive;
{
    return [NSKeyedArchiver archivedDataWithRootObject:self.dict];
}

+ (instancetype _Nullable) unarchiveFromData: (NSData * _Nonnull) keyedArchiverData;
{
    NSMutableDictionary *dict = [NSKeyedUnarchiver unarchiveObjectWithData:keyedArchiverData];
    if (nil == dict) return nil;
    
    return [[SMMutableDictionary alloc] initWithDictionary:dict];
}

- (NSUInteger) count;
{
    return self.dict.count;
}

- (id) objectForKey:(id)aKey;
{
    return [self.dict objectForKey:aKey];
}

- (NSEnumerator *)keyEnumerator;
{
    return [self.dict keyEnumerator];
}

- (void) setObject:(id)anObject forKey:(id<NSCopying>)aKey;
{
    [self.dict setObject:anObject forKey:aKey];
    if (self.delegate) {
        [self.delegate dictionaryWasChanged:self];
    }
}

- (void) removeObjectForKey:(id)aKey;
{
    [self.dict removeObjectForKey:aKey];
    if (self.delegate) {
        [self.delegate dictionaryWasChanged:self];
    }
}

- (instancetype) mutableCopy;
{
    SMMutableDictionary *dict = [[SMMutableDictionary alloc] initWithDictionary:self];
    return dict;
}

@end
