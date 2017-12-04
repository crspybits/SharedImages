//
//  CoreData.h
//  Petunia
//
//  Created by Christopher Prince on 6/11/13.
//  Copyright (c) 2013 Christopher Prince. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>
#import <UIKit/UIKit.h>

#ifdef SMCOMMONLIB
#import <SMCommon/NSObject+TargetsAndSelectors.h>
#else
#import "NSObject+TargetsAndSelectors.h"
#endif

@class CoreData;

@protocol CoreDataModel <NSObject>

@required

+ (NSString * _Nonnull) entityName;

@optional

// This doesn't make assumptions about uuid's.
+ (NSManagedObject * _Nonnull) newObject;

// Instead of calling the generic removeObject method for Core Data, a more specialized method can be useful to take into account removing related objects.
- (void) removeObject;

// If you give this, the presumption (which is typical) is that there is only a single CoreData session (e.g., a NSManagedObjectContext) for the entity/NSManagedObject sub-type.
+ (CoreData * _Nonnull) sessionForEntity;

// Creates a UUID for the object iff makeUUID = YES; object must have an NSManagedObject field/property named "uuid", of type NSString.
+ (NSManagedObject * _Nonnull) newObjectAndMakeUUID: (BOOL) makeUUID;

+ (NSArray * _Nullable) fetchAllObjects;
+ (NSArray * _Nullable) fetchObjectsWithModifyingFetchRequest: (void (^ _Nonnull)(NSFetchRequest * _Nonnull)) fetchRequestModifier;

// This is relatively efficient: It doesn't fetch all objects into an array.
+ (NSUInteger) countOfObjects;

@end

@interface CoreData : NSObject

// Keys for the dictionary in initWithOptions.

extern const NSString * _Nonnull CoreDataBundleModelName; // the model name
extern const NSString * _Nonnull CoreDataSqlliteFileName;
extern const NSString * _Nonnull CoreDataSqlliteBackupFileName;

// This key is optional; useful for locating core data models outside of the main bundle (e.g., in a framework).
extern const NSString * _Nonnull CoreDataModelBundle; // Bundle where model is located.

extern const NSString * _Nonnull CoreDataPrivateQueue;
extern const NSString * _Nonnull CoreDataLightWeightMigration;

#define COREDATA_BUNDLE_MODEL_NAME                      CoreDataBundleModelName
#define COREDATA_SQLITE_FILE_NAME                       CoreDataSqlliteFileName
#define COREDATA_SQLITE_BACKUP_FILE_NAME                CoreDataSqlliteBackupFileName
#define COREDATA_MODEL_BUNDLE                           CoreDataModelBundle

// If given, with a value of @YES/true, then the privateQueue concurrency option is used. Use this when you may not be accessing the Core Data objects strictly on the main thread. See also https://developer.apple.com/library/content/documentation/Cocoa/Conceptual/CoreData/Concurrency.html
#define COREDATA_PRIVATE_QUEUE                          CoreDataPrivateQueue

// Enable lightweight migration; give any value with this key to enable it.
#define COREDATA_LIGHTWEIGHT_MIGRATION                  CoreDataLightWeightMigration

// Keys as above.
- (instancetype _Nonnull) initWithOptions: (NSDictionary * _Nonnull) dictionary;

// Only use these if you want to have just a single managed object context.
+ (void) useDefaultSession: (CoreData * _Nonnull) defaultSession;
+ (instancetype _Nonnull) defaultSession;

// If you want to have multiple managed object contexts, you can use this.
+ (void) registerSession: (CoreData * _Nonnull) coreData forName: (NSString * _Nonnull) sessionName;
+ (instancetype _Nonnull) sessionNamed: (NSString * _Nonnull) sessionName;

- (void) setupCustomAlert: (void (^ _Nullable)(UIAlertView * _Nonnull alert)) alert;

@property (strong, nonatomic, readonly) NSManagedObjectContext * _Nonnull context;

// Get callbacks when managed objects are deleted, updated, or inserted. Based on NSManagedObjectContextObjectsDidChangeNotification. The keys used in the associated NSMutableDictionary's are: NSDeletedObjectsKey, NSUpdatedObjectsKey, NSInsertedObjectsKey
@property (strong, nonatomic, readonly) NSObject<TargetsAndSelectors> * _Nonnull didDeleteObjects;
@property (strong, nonatomic, readonly) NSObject<TargetsAndSelectors> * _Nonnull didUpdateObjects;
@property (strong, nonatomic, readonly) NSObject<TargetsAndSelectors> * _Nonnull didInsertObjects;

// Allow or disallow undo. Default is off.
- (void) undoIsOn: (BOOL) onOff;

// No effect if undo is off.
- (void) undo;

// You must use this for any sequence of CoreData operations if you have selected COREDATA_PRIVATE_QUEUE when creating the CoreData object.
- (void) performAndWait:  (nonnull void (^)(void ) )  block;

// We need a saveContext that returns void for the cases where we are doing a performSelector
- (void) saveContextVoidReturn;

- (BOOL) saveContextWithError: (NSError * _Nullable * _Nullable) error;
- (BOOL) saveContext;

// These methods can return nil.
- (NSManagedObject * _Nullable) newObjectWithEntityName: (NSString * _Nonnull) entityName;

// If there is an error, error is returned non-nil. In this case, a UIAlertView will have been given to the user. Nil is returned in this case. With no error, and no objects found, nil is returned.
// 1/21/16; I have now changed the NSError references to _Nullable _Nullable to be consistent with "The particular type NSError ** is so often used to return errors via method parameters that it is always assumed to be a nullable pointer to a nullable NSError reference." (https://developer.apple.com/swift/blog/?id=25).
- (NSArray * _Nullable) fetchAllObjectsWithEntityName: (NSString * _Nonnull) entityName andError: (NSError * _Nullable * _Nullable) error;
- (NSArray * _Nullable) fetchObjectsWithEntityName: (NSString * _Nonnull) entityName error: ( NSError  * _Nullable * _Nullable) error modifyingFetchRequestWith: (void (^ _Nullable)(NSFetchRequest * _Nonnull)) fetchRequestModifier;

- (NSFetchRequest * _Nullable) fetchRequestWithEntityName: (NSString * _Nonnull) entityName modifyingFetchRequestWith: (void (^ _Nullable)(NSFetchRequest * _Nonnull)) fetchRequestModifier;

// Get the total number of objects, with that entity name, in the context.
// If there is an error, error is returned non-nil. In this case, a UIAlertView will have been given to the user. Returns 0 on an error.
- (NSUInteger) countOfObjectsWithEntityName: (NSString * _Nonnull ) entityName andError: (NSError * _Nullable * _Nullable) error;

- (void) removeObject: (NSManagedObject * _Nonnull) managedObject;

@end
