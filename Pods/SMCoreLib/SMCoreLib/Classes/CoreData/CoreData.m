//
//  CoreData.m
//  Petunia
//
//  Created by Christopher Prince on 6/11/13.
//  Copyright (c) 2013 Christopher Prince. All rights reserved.
//

/* I found the usage of these names really confusing at first. The bundle model name refers to the name of the directory/folder in XCode containing all the models, not the name of the model versions within that directory. When you give a modelResource name to:
 
 NSURL *modelURL = [[NSBundle mainBundle] URLForResource:modelResource withExtension:@"momd"];
 NSManagedObjectModel *theManagedObjectModel = [[NSManagedObjectModel alloc] initWithContentsOfURL:modelURL];
 
 That modelResource name is the directory/folder in Xcode.
 
 When you do:
 NSURL *storeURL = [[self applicationDocumentsDirectory] URLByAppendingPathComponent:storeFileName];
 NSError *error = nil;
 
 if (![persistentStoreCoordinator addPersistentStoreWithType:NSSQLiteStoreType configuration:nil URL:storeURL options:options error:&error]) {
 // handle error
 }
 
 The storeFileName is the name of your .sqlite file in the Documents folder/directory (this is *not* in the bundle).
 
 Also, when you migrate from one model version to another model version, by default, the .sqlite file name remains the same.
 
 See also: http://stackoverflow.com/questions/2310216/implementation-of-automatic-lightweight-migration-for-core-data-iphone
 */

#import "CoreData.h"

#ifdef SMCOMMONLIB
#import <SMCommon/SMUIMessages.h>
#import <SMCommon/UserMessage.h>
#import <SMCommon/SMAssert.h>
#else
#import "SMUIMessages.h"
#import "UserMessage.h"
#import "SMAssert.h"
#import "NSObject+Extras.h"
#import "NSObject+TargetsAndSelectors.h"
#endif

const NSString *CoreDataBundleModelName = @"CoreDataModelName";
const NSString *CoreDataSqlliteFileName = @"CoreDataSqliteFileName";
const NSString *CoreDataSqlliteBackupFileName = @"CoreDataSqliteBackupFileName";
const NSString *CoreDataModelBundle = @"CoreDataModelBundle";
const NSString *CoreDataPrivateQueue = @"CoreDataPrivateQueue";
const NSString *CoreDataLightWeightMigration = @"CoreDataLightWeightMigration";

// See [1] below.
/*
// App-Swift.h is needed for SMDefs
// You must change the Objective-C Generated Interface Header Name to: App-Swift.h
#ifdef SMCORELIB
#import <SMCoreLib/SMCoreLib-Swift.h>
#else
//#import "SMCoreLib-Swift.h"
#endif
*/

@interface CoreData()
@property (nonatomic, strong) NSManagedObjectModel *managedObjectModel;
@property (nonatomic, strong)  NSPersistentStoreCoordinator *persistentStoreCoordinator;
@property (nonatomic, strong)  NSManagedObjectContext *managedObjectContext;

@property (nonatomic) BOOL setupError;
@property (nonatomic, strong) NSURL *sqliteURL;
@property (nonatomic, strong) NSURL *sqliteBackupURL;

@property (nonatomic, strong) void (^customAlert)(UIAlertView *alert);

//@property (nonatomic) NSUInteger currentSqliteFileIndex;
//@property (nonatomic, strong) NSString *currentSqliteFileName;
//@property (nonatomic, strong) NSString *currentBundleFileName;

@property (strong, nonatomic) NSObject<TargetsAndSelectors> *didDeleteObjects;
@property (strong, nonatomic) NSObject<TargetsAndSelectors> *didUpdateObjects;
@property (strong, nonatomic) NSObject<TargetsAndSelectors> *didInsertObjects;

@property (nonatomic, strong) NSDictionary *options;
@end

@implementation CoreData
#pragma mark - Core Data stack

- (NSURL *) sqliteURL {
    if (!_sqliteURL) {
        // SPASLogDetail(@"%@", self.options[COREDATA_SQLITE_FILE_NAME]);
        _sqliteURL = [[self applicationDocumentsDirectory] URLByAppendingPathComponent:self.options[COREDATA_SQLITE_FILE_NAME]];
    }
    return _sqliteURL;
}

- (NSURL *) sqliteBackupURL {
    if (!_sqliteBackupURL) {
        // SPASLogDetail(@"%@", self.options[COREDATA_SQLITE_BACKUP_FILE_NAME]);
        _sqliteBackupURL = [[self applicationDocumentsDirectory] URLByAppendingPathComponent:self.options[COREDATA_SQLITE_BACKUP_FILE_NAME]];
    }
    return _sqliteBackupURL;
}

- (void) migrationSetup {
    
    NSDictionary *options =
    [NSDictionary dictionaryWithObjectsAndKeys:
     [NSNumber numberWithBool:YES], NSMigratePersistentStoresAutomaticallyOption,
     [NSNumber numberWithBool:YES], NSInferMappingModelAutomaticallyOption, nil];
    
    [[NSFileManager defaultManager] removeItemAtURL:self.sqliteBackupURL error:nil];
    if (![[NSFileManager defaultManager] copyItemAtURL:self.sqliteURL toURL:self.sqliteBackupURL error:nil]) {
        // SPASLogFile(@"CoreData.migrationSetup: Could not make backup of sqlite file");
    }
    
    [self setupWithMigrationOptions:options];
}

- (void) setupCustomAlert: (void (^)(UIAlertView *alert)) alert;
{
    self.customAlert = alert;
}

- (void) errorWithMessage: (NSString *) messageString;
{
    NSString *message = [NSString stringWithFormat:@"Internal error in Core Data: Did you change your model?: %@", messageString];
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:message message:@"Please contact customer support" delegate:nil cancelButtonTitle:[[SMUIMessages session] OkMsg] otherButtonTitles: nil];
    if (self.customAlert) {
        self.customAlert(alert);
    }
    // SPASLogFile(@"%@", message);
}

- (void) setupWithMigrationOptions: (NSDictionary *) migrationOptions {
    self.managedObjectModel = [self managedObjectModelForBundleResource:self.options[COREDATA_BUNDLE_MODEL_NAME] withBundle:self.options[COREDATA_MODEL_BUNDLE]];
    if (!self.managedObjectModel) {
        [self errorWithMessage: @"No managed object model"];
        return;
    }
    
    self.persistentStoreCoordinator = [self persistentStoreCoordinatorWith:self.managedObjectModel];
    if (!self.persistentStoreCoordinator) {
        [self errorWithMessage:@"No persistent store coordinator"];
        return;
    }
    
    if (! [self addSqliteFileTo:_persistentStoreCoordinator withSqliteFileName:self.options[COREDATA_SQLITE_FILE_NAME] andOptions:migrationOptions]) {
        [self errorWithMessage: @"Could not add sqlite file to coordinator"];
        return;
    }
    
    self.managedObjectContext = [self managedObjectContextWith:self.persistentStoreCoordinator];
    if (!self.managedObjectContext) {
        [self errorWithMessage: @"No managed object context"];
        return;
    }
    
    // SPASLog(@"CoreData.setupWithMigrationOptions: options: %@", migrationOptions);
}

// the selector will be called when an NSManagedObject is deleted; it has a parameter of an NSSet of managed objects.
- (instancetype) initWithOptions: (NSDictionary *) dictionary;
{
    self = [super init];
    if (self) {
        AssertIf(!dictionary[COREDATA_BUNDLE_MODEL_NAME], @"Core Data Bundle Model Name");
        AssertIf(!dictionary[COREDATA_SQLITE_FILE_NAME], @"Core Data Sqlite File Name");
        AssertIf(!dictionary[COREDATA_SQLITE_BACKUP_FILE_NAME], @"Core Data Sqlite Backup File name");
    
        self.options = dictionary;
    
        // Check to see if there is any .sqllite file. If there is none, then presumably we are starting for the first time.

// 7/3/16; [1]; Commenting this out because Cocoapods isn't dealing with using Swift from Objective-C. How sad. :(. https://github.com/CocoaPods/CocoaPods/issues/3767
#if 0
        BOOL databaseExists = [[NSFileManager defaultManager] fileExistsAtPath:[[self sqliteURL] path]];
        
        // Right now, this only deals with a single change from NSUserDefaults model index to the new model index. Will need to, eventually, deal with the case where... OR does it? Can the auto migration of Core Data handle multiple steps in version change?
        if (databaseExists &&
            (SMDefs.CURR_CORE_DATA_MODEL.intValue != SMDefs.CURR_CORE_DATA_MODEL.intDefault)) {
            SMDefs.CURR_CORE_DATA_MODEL.intValue = SMDefs.CURR_CORE_DATA_MODEL.intDefault;
            [self migrationSetup];
        } else {
            // Either the database doesn't exist, or the model version in the .sqllite file is the same as the current version.
            [self setupWithMigrationOptions:nil];
        }
#endif

        if (dictionary[COREDATA_LIGHTWEIGHT_MIGRATION]) {
            [self migrationSetup];
        }
        else {
            [self setupWithMigrationOptions:nil];
        }

        // This has to come after the setup above. managedObjectContext does not get set until the setup occurs. 
        [[NSNotificationCenter defaultCenter]
         addObserver:self
         selector:@selector(objectContextDidChange:)
         name:NSManagedObjectContextObjectsDidChangeNotification
         object:self.managedObjectContext];
        
        self.didDeleteObjects = [NSObject new];
        [self.didDeleteObjects resetTargets];
        
        self.didUpdateObjects = [NSObject new];
        [self.didUpdateObjects resetTargets];
        
        self.didInsertObjects = [NSObject new];
        [self.didInsertObjects resetTargets];
    }
    
    return self;
}

static CoreData* s_sharedInstance = nil;

+ (void) useDefaultSession: (CoreData * _Nonnull) defaultSession;
{
    s_sharedInstance = defaultSession;
}

+ (instancetype _Nonnull) defaultSession;
{
    return s_sharedInstance;
}

- (void) objectContextDidChange: (NSManagedObjectContext *) managedObjectContext {
    NSDictionary *userInfo = managedObjectContext.userInfo;
    
    void (^doCallbacks)(NSString *, NSObject<TargetsAndSelectors> *) =
        ^(NSString *key, NSObject<TargetsAndSelectors> *targetAndSelectorObj){
            
        id managedObjects = userInfo[key];
            
        if (managedObjects) {
            // SPASLog(@"managed objects (%@): %@", key, managedObjects);
            [targetAndSelectorObj forEachTargetInCallbacksDo:^(id target, SEL selector, NSMutableDictionary *dict) {
                dict[key] = managedObjects;
                [target performVoidReturnSelector:selector];
            }];
        }
    };
    
    doCallbacks(NSDeletedObjectsKey, self.didDeleteObjects);
    doCallbacks(NSUpdatedObjectsKey, self.didUpdateObjects);
    doCallbacks(NSInsertedObjectsKey, self.didInsertObjects);
}

// Allow or disallow undo. Default is off.
- (void) undoIsOn: (BOOL) undoIsOn {
    /*
    NSManagedObjectContext *managedObjectContext = [self managedObjectContext];
    NSUndoManager *undoManager = nil;
    
    if (undoIsOn) {
        undoManager = [[NSUndoManager alloc] init];
    }
    
    [managedObjectContext setUndoManager:undoManager];
     */
}

// No effect if undo is off.
- (void) undo {
    /*
    NSManagedObjectContext *managedObjectContext = [self managedObjectContext];
    [managedObjectContext undo];
     */
}

// We need a saveContext that returns void because we are doing a performSelector
- (void) saveContextVoidReturn;
{
    [self saveContext];
}

- (BOOL) saveContextWithError: (NSError * _Nullable * _Nullable) error;
{
    if (self.managedObjectContext != nil) {
        // SPASLog(@"CoreData.saveContext: %d", [self.managedObjectContext hasChanges]);
        if ([self.managedObjectContext hasChanges] && ![self.managedObjectContext save:error]) {
            // Replace this implementation with code to handle the error appropriately.
            // abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
            NSString *message = [NSString stringWithFormat:@"Unresolved error %@, %@", *error, [*error userInfo]];
            // SPASLogFile(@"%@", message);
            [self errorWithMessage: message];
            return NO;
        } else {
            return YES;
        }
    }
    return NO;
}

- (BOOL)saveContext;
{
    NSError *error = nil;
    BOOL result = [self saveContextWithError:&error];
    return result;
}

// Returns the managed object context for the application.
// If the context doesn't already exist, it is created and bound to the persistent store coordinator for the application.
- (NSManagedObjectContext *)managedObjectContextWith: (NSPersistentStoreCoordinator *) persistentStoreCoordinator
{
    NSManagedObjectContext *managedObjectContext;
    
    // SPASLog(@"CoreData.managedObjectContextWith: self.options[COREDATA_PRIVATE_QUEUE] %@", self.options[COREDATA_PRIVATE_QUEUE]);
    // SPASLog(@"CoreData.managedObjectContextWith: [self.options[COREDATA_PRIVATE_QUEUE] boolValue] %d", [self.options[COREDATA_PRIVATE_QUEUE] boolValue]);
    
    if (self.options[COREDATA_PRIVATE_QUEUE]
        && ([self.options[COREDATA_PRIVATE_QUEUE] boolValue])) {
        managedObjectContext = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSPrivateQueueConcurrencyType];
    }
    else {
        // This is old, but maintains backward compatiblity with previous versions of the CoreData class.
        managedObjectContext = [[NSManagedObjectContext alloc] init];
    }
    
    [managedObjectContext setPersistentStoreCoordinator:persistentStoreCoordinator];
    
    // SPASLog(@"CoreData.managedObjectContextWith: %@", managedObjectContext);
    return managedObjectContext;
}

- (NSURL *) getModelURLForBundleResource: (NSString *) modelResource from: (NSBundle *) bundle;
{
    NSURL *modelURL = [bundle URLForResource:modelResource withExtension:@"mom"];
    
    // CGP; 5/5/16; I've no clue why, but today, "mom" isn't working for an example app, but "momd" is!
    if (!modelURL) {
        modelURL = [bundle URLForResource:modelResource withExtension:@"momd"];
    }
    
    return modelURL;
}

// Returns the managed object model for the application.
// If the model doesn't already exist, it is created from the application's model.
- (NSManagedObjectModel *)managedObjectModelForBundleResource: (NSString *) modelResource withBundle: (NSBundle *) modelBundle;
{
    // Check if first if we can find the model in the main bundle.
    NSURL *modelURL = [self getModelURLForBundleResource:modelResource from:[NSBundle mainBundle]];

    if (!modelURL && modelBundle) {
        // This is how I'm locating the CoreData model for my custom framework-- relative to the framework viewed as a bundle.
        modelURL = [self getModelURLForBundleResource:modelResource from:modelBundle];
    }
    
    AssertIf(nil == modelURL, "YIKES: modelURL is nil: Couldn't find your Core Data model!")
    
    NSManagedObjectModel *theManagedObjectModel = [[NSManagedObjectModel alloc] initWithContentsOfURL:modelURL];
    return theManagedObjectModel;
    
    /* 1/19/15; I was using this before today but, I'm now using multiple models and this doesn't seem clear how it will distinguish between models. Plus, it's not finding models in my Cocoa Touch Framework.
    // See http://stackoverflow.com/questions/4536414/cant-find-momd-file-core-data-problems
    NSManagedObjectModel *theManagedObjectModel = [NSManagedObjectModel mergedModelFromBundles:nil];
    return theManagedObjectModel;
    */

    /*
    NSURL *modelURL = [[NSBundle mainBundle] URLForResource:modelResource withExtension:@"momd"];
    //
    if (!modelURL) {
        modelURL = [[NSBundle mainBundle] URLForResource:modelResource withExtension:@"mom"];
    }
    
    SPASLogDetail(@"modelResource: %@; modelURL: %@", modelResource, modelURL);
    NSManagedObjectModel *theManagedObjectModel = [[NSManagedObjectModel alloc] initWithContentsOfURL:modelURL];
    return theManagedObjectModel;
     */
}

// Persistent store coordinator for current bundle resource.
- (NSPersistentStoreCoordinator *) persistentStoreCoordinatorWith: (NSManagedObjectModel *) managedObjectModel  {
    NSPersistentStoreCoordinator *persistentStoreCoordinator = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:managedObjectModel];
    return persistentStoreCoordinator;
}

// options can be nil.
- (BOOL) addSqliteFileTo: (NSPersistentStoreCoordinator *) persistentStoreCoordinator withSqliteFileName: (NSString *) storeFileName andOptions: (NSDictionary *) options
{
    NSError *error = nil;

    if (![persistentStoreCoordinator addPersistentStoreWithType:NSSQLiteStoreType configuration:nil URL:self.sqliteURL options:options error:&error]) {
        /*
         Replace this implementation with code to handle the error appropriately.
         
         abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
         
         Typical reasons for an error here include:
         * The persistent store is not accessible;
         * The schema for the persistent store is incompatible with current managed object model.
         Check the error message to determine what the actual problem was.
         
         
         If the persistent store is not accessible, there is typically something wrong with the file path. Often, a file URL is pointing into the application's resources directory instead of a writeable directory.
         
         If you encounter schema incompatibility errors during development, you can reduce their frequency by:
         * Simply deleting the existing store:
         [[NSFileManager defaultManager] removeItemAtURL:storeURL error:nil]
         
         * Performing automatic lightweight migration by passing the following dictionary as the options parameter:
         @{NSMigratePersistentStoresAutomaticallyOption:@YES, NSInferMappingModelAutomaticallyOption:@YES}
         
         Lightweight migration will only work for a limited set of schema changes; consult "Core Data Model Versioning and Data Migration Programming Guide" for details.
         
         */
        // SPASLogFile(@"CoreData.addSqliteFileTo: Unresolved error %@, %@",
        //            error, [error userInfo]);
        return NO;
    }
    return YES;
}

#pragma mark - Application's Documents directory

/*
+ (NSURL *) storeURL {
    NSURL *storeURL = [[CoreData applicationDocumentsDirectory] URLByAppendingPathComponent:@"Model.sqlite"];
    return storeURL;
}*/

// Returns the URL to the application's Documents directory.
- (NSURL *)applicationDocumentsDirectory
{
    return [[[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask] lastObject];
}

/*
- (NSString *) currentSqliteFileName {
    NSString *fileName = SQLITE_MODEL_FILES[0];
    SPASLog(@"CoreData.currentSqliteFileName: bundleFileName: %@", fileName);
    return fileName;
}

- (NSUInteger) currentSqliteFileIndex {
    SPASLog(@"CoreData.currentSqliteFileIndex");
    NSNumber *currIndex = [[NSUserDefaults standardUserDefaults] objectForKey:STANDARD_USER_DEFAULTS_CURR_SQLITE_FILE_INDEX];
    
    if (! currIndex) return 0;
    return [currIndex integerValue];
}

- (void) setCurrentSqliteFileIndex: (NSUInteger) currIndex {
    NSNumber *currIndexNum = [[NSNumber alloc] initWithInt:currIndex];
    [[NSUserDefaults standardUserDefaults] setObject:currIndexNum forKey:STANDARD_USER_DEFAULTS_CURR_SQLITE_FILE_INDEX];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (NSString *) currentBundleFileName {
    NSString *fileName =  BUNDLE_MODEL_FILES[0];
    SPASLog(@"CoreData.currentBundleFileName: bundleFileName: %@", fileName);
    return fileName;
}
*/

#pragma mark - Misc app helper methods

- (NSManagedObject *) newObjectWithEntityName: (NSString *) entityName;
{
    AssertIf(nil == self.context, "Yikes: self.context was nil!");
    
    NSManagedObject* object =
        [NSEntityDescription insertNewObjectForEntityForName:entityName
                                  inManagedObjectContext:self.context];
    return object;
}

- (NSArray * _Nullable) fetchAllObjectsWithEntityName: (NSString * _Nonnull) entityName andError: (NSError * _Nullable * _Nullable) error;
{
    return [self fetchObjectsWithEntityName:entityName error:error modifyingFetchRequestWith:nil];
}

- (NSArray * _Nullable) fetchObjectsWithEntityName: (NSString * _Nonnull) entityName error: (NSError * _Nullable * _Nullable) error modifyingFetchRequestWith: (void (^ _Nullable)(NSFetchRequest * _Nonnull)) fetchRequestModifier;
{
    if (error) *error = nil;
    
    // SPASLogDetail(@"entityName: %@", entityName);
    // SPASLogDetail(@"dict: %@", self.options);
    AssertIf([entityName length] == 0, @"No entity name given!");
    
    NSFetchRequest *fetchRequest = [self fetchRequestWithEntityName:entityName modifyingFetchRequestWith:fetchRequestModifier];
    
    NSArray *objs = nil;
    
    if (fetchRequest) {
        objs = [self.context executeFetchRequest:fetchRequest error:error];
    }
    
    if (error && *error) {
        NSString *message = [NSString stringWithFormat:@"Error: %@", *error];
        // SPASLogFile(@"%@", message);

        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"There was an internal error fetching objects with Core Data" message:message delegate:nil cancelButtonTitle:[[SMUIMessages session] OkMsg] otherButtonTitles:nil];
        [[UserMessage session] showAlert:alert ofType:UserMessageTypeError];
    }
    
    return objs;
}

- (NSFetchRequest * _Nullable) fetchRequestWithEntityName: (NSString * _Nonnull) entityName modifyingFetchRequestWith: (void (^ _Nullable)(NSFetchRequest * _Nonnull)) fetchRequestModifier;
{
    NSFetchRequest *request = nil;
    
    if (self.context) {
        NSEntityDescription* entity = [NSEntityDescription entityForName:entityName inManagedObjectContext:self.context];
        request = [NSFetchRequest new];
        request.entity = entity;
        
        if (fetchRequestModifier) {
            fetchRequestModifier(request);
        }
    }
    
    return request;
}

- (NSManagedObjectContext *) context;
{
    return self.managedObjectContext;
}

- (NSUInteger) countOfObjectsWithEntityName: (NSString * _Nonnull ) entityName andError: (NSError * _Nullable * _Nullable) error;
{
    if (error) *error = nil;
    NSUInteger count = 0;
    
    if (self.context) {
        NSFetchRequest *fetchRequest = [NSFetchRequest fetchRequestWithEntityName:entityName];
        // What happens if there was an error with the entityName? E.g., does this throw an exception or return fetchRequest == nil?
        count = [self.context countForFetchRequest:fetchRequest error:error];
    }
    
    if ((error && *error) || !self.context) {
        NSString *message = [NSString stringWithFormat:@"Error: %@; context= %@", (error ? *error : @"") , self.context];
        // SPASLogFile(@"%@", message);
        
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"There was an internal error counting objects with Core Data" message:message delegate:nil cancelButtonTitle:[[SMUIMessages session] OkMsg] otherButtonTitles:nil];
        [[UserMessage session] showAlert:alert ofType:UserMessageTypeError];
        count = 0;
    }
    
    return count;
}

- (void) removeObject: (NSManagedObject * _Nonnull) managedObject;
{
    // SPASLogDetail(@"managedObject: %@", managedObject);
    [self.context deleteObject: managedObject];
}

static NSMutableDictionary *sessions = nil;

+ (void) registerSession: (CoreData * _Nonnull) coreData forName: (NSString * _Nonnull) sessionName;
{
    if (!sessions) {
        sessions = [NSMutableDictionary new];
    }
    
    sessions[sessionName] = coreData;
}

+ (instancetype _Nonnull) sessionNamed: (NSString * _Nonnull) sessionName;
{
    CoreData *result = nil;
    
    result = sessions[sessionName];
    AssertIf(nil == result, @"Yikes: No CoreData session for: %@", sessionName);
    
    return result;
}

- (void) performAndWait: (nonnull void (^)(void ) )  block;
{
    [self.managedObjectContext performBlockAndWait:block];
}

@end
