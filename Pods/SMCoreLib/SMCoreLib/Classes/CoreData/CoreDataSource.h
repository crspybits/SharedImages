//
//  CoreDataTableViewController.h
//  Petunia
//
//  Created by Christopher Prince on 5/4/13.
//  Copyright (c) 2013 Christopher Prince. All rights reserved.
//

// A class integrating a table view and core data.

#import <UIKit/UIKit.h>
#import <CoreData/CoreData.h>
#import "CoreData.h"

@class CoreDataSource;

@protocol CoreDataSourceDelegate <NSObject>

@required

// This must have sort descriptor(s) because that is required by the NSFetchedResultsController, which is used internally by this class.
- (NSFetchRequest *) coreDataSourceFetchRequest: (CoreDataSource *) cds;

- (NSManagedObjectContext *) coreDataSourceContext: (CoreDataSource *) cds;

@optional

// Should return YES iff the context save was successful.
- (BOOL) coreDataSourceSaveContext: (CoreDataSource *) cds;

- (void) coreDataSourceWillChangeContent: (CoreDataSource *) cds;
- (void) coreDataSourceDidChangeContent: (CoreDataSource *) cds;

- (void) coreDataSource: (CoreDataSource *) cds objectWasDeleted: (NSIndexPath *) indexPathOfDeletedObject;
- (void) coreDataSource: (CoreDataSource *) cds objectWasInserted: (NSIndexPath *) indexPathOfInsertedObject;
- (void) coreDataSource: (CoreDataSource *) cds objectWasUpdated: (NSIndexPath *) indexPathOfUpdatedObject;
- (void) coreDataSource: (CoreDataSource *) cds objectWasMovedFrom: (NSIndexPath *) oldIndexPath to: (NSIndexPath *) newIndexPath;

@end

@interface CoreDataSource : NSObject

// Designated initializer; will not return nil.
- (instancetype ) initWithDelegate: (id<CoreDataSourceDelegate>) delegate;

// Call this in order to fetch results for NSFetchedResultsController; e.g., call this in your viewWillAppear. Returns YES iff successful.
- (BOOL) fetchData;

// The following are OK to call after successfully calling fetchData.

- (NSUInteger) numberOfSections;
- (NSUInteger) numberOfRowsInSection: (NSUInteger) section;

- (NSManagedObject *) objectAtIndexPath: (NSIndexPath *) indexPath;

- (void) deleteObjectAtIndexPath: (NSIndexPath *) indexPath;

@end

