//
//  Defaults.m
//  Petunia
//
//  Created by Christopher Prince on 12/11/14.
//  Copyright (c) 2014 Spastic Muffin, LLC. All rights reserved.
//

#import "Defaults.h"
#import "SPASLog.h"
#import "SMAssert.h"

@interface Defaults()
@property (nonatomic, strong) NSDictionary *currentItems;
@end

@implementation Defaults

+ (instancetype) session;
{
    static Defaults* s_sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        s_sharedInstance = [[self alloc] init];
        s_sharedInstance.currentItems = [s_sharedInstance items];
        SPASLogDetail(@"class: %@", [s_sharedInstance class]);
    });
    
    return s_sharedInstance;
}

- (NSDictionary *) items;
{
    return nil;
}

- (void) reset;
{
    for (NSString *key in self.items.allKeys) {
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:key];
    }
    
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (void) resetValueFor: (NSString *) nsUserDefaultsKey;
{
    NSArray *itemInfo = self.items[nsUserDefaultsKey];
    AssertActionIf(!itemInfo, @"Expected non-nil data!", {return;});
    
    id defaultValue = itemInfo[DEFAULT_INDEX_DEFAULT];
    DefaultsType defaultsType = [itemInfo[DEFAULT_INDEX_TYPE] integerValue];

    switch (defaultsType) {
        case DefaultsTypePrimitiveObject:
            [[NSUserDefaults standardUserDefaults]
                setObject:defaultValue forKey:nsUserDefaultsKey];
            break;
            
        case DefaultsTypeArchivableObject: {
            id archivedValue = [NSKeyedArchiver archivedDataWithRootObject:defaultValue];
            [[NSUserDefaults standardUserDefaults]
             setObject:archivedValue forKey:nsUserDefaultsKey];
        }
    }
    
    [[NSUserDefaults standardUserDefaults] synchronize];
}

+ (id) getValueFor: (NSString *) nsUserDefaultsKey;
{
    // I'm not quite sure why [self session].currentItems is a syntax error...
    // SPASLogDetail(@"key: %@, items: %@", nsUserDefaultsKey, [[self session] currentItems]);
    NSArray *itemInfo = [[self session] currentItems][nsUserDefaultsKey];
    AssertActionIf(!itemInfo, @"Expected non-nil data!", {return nil;});
    DefaultsType defaultsType = [itemInfo[DEFAULT_INDEX_TYPE] integerValue];

    id value = [[NSUserDefaults standardUserDefaults] objectForKey:nsUserDefaultsKey];
    if (!value) {
        id defaultValue = itemInfo[DEFAULT_INDEX_DEFAULT];
        if([defaultValue isEqual:[NSNull null]]) {
            return nil;
        }
        return defaultValue;
    }
    
    switch (defaultsType) {
        case DefaultsTypePrimitiveObject:
            return value;
            
        case DefaultsTypeArchivableObject: {
                id unarchivedValue = [NSKeyedUnarchiver unarchiveObjectWithData:value];
                return unarchivedValue;
            }
    }
}

+ (void) setValue: (id) value for: (NSString *) nsUserDefaultsKey;
{
    NSArray *itemInfo = [[self session] currentItems][nsUserDefaultsKey];
    AssertActionIf(!itemInfo, @"Expected non-nil data!", {return;});
    DefaultsType defaultsType = [itemInfo[DEFAULT_INDEX_TYPE] integerValue];
    
    if (nil == value) {
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:nsUserDefaultsKey];
    } else {
        switch (defaultsType) {
            case DefaultsTypePrimitiveObject:
                [[NSUserDefaults standardUserDefaults] setObject:value forKey:nsUserDefaultsKey];
                break;
                
            case DefaultsTypeArchivableObject: {
                id archivedValue = [NSKeyedArchiver archivedDataWithRootObject:value];
                [[NSUserDefaults standardUserDefaults]
                    setObject:archivedValue forKey:nsUserDefaultsKey];
            }
        }
    }
    
    [[NSUserDefaults standardUserDefaults] synchronize];
}

+ (void) setValue: (id) value forDefKey: (NSString *) nsUserDefaultsKey;
{
    [self setValue:value for:nsUserDefaultsKey];
}

@end
