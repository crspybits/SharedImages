//
//  CoreDataSource.m
//  Catsy
//
//  Created by Christopher Prince on 6/29/15
//  Copyright (c) 2015 Christopher Prince. All rights reserved.
//

#import "CoreDataSource.h"
#import "SMAssert.h"

/* The message: "The model used to open the store is incompatible with the one used to create the store"
 Seems to come when you have an old version of the .sqlite file, i.e., one with entity descriptions created earlier but you have now added new entity descriptions and they are not in the .sqlite file. I will need to handle this eventually with migration.
 */

@interface CoreDataSource() <NSFetchedResultsControllerDelegate>
@property (strong, nonatomic) NSFetchedResultsController *fetchedResultsController;
//@property (strong, nonatomic) NSIndexPath *indexPathForDeletion;
@property (nonatomic, weak) id<CoreDataSourceDelegate> delegate;
@end

@implementation CoreDataSource

- (instancetype) initWithDelegate: (id<CoreDataSourceDelegate>) delegate;
{
    self = [super init];
    if (self) {
        AssertIf(!delegate, @"You must give a delegate!");
        self.delegate = delegate;
    }
    return self;
}

- (void) saveContext;
{
    if ([self.delegate respondsToSelector:@selector(coreDataSourceSaveContext:)]) {
        [self.delegate coreDataSourceSaveContext:self];
    }
}

- (void) deleteObjectAtIndexPath: (NSIndexPath *) indexPath;
{
    // 5/20/16; Fixed bug. This used to use a property called self.indexPathForDeletion, which was never assigned!
    NSManagedObject *objectToDeleted = [self.fetchedResultsController objectAtIndexPath:indexPath];
    SPASLogDetail(@"objectToDeleted: %@", objectToDeleted);

    [[self.delegate coreDataSourceContext:self] deleteObject:objectToDeleted];
    [self saveContext];
}

- (void)controllerWillChangeContent:(NSFetchedResultsController *)controller {
    if ([self.delegate respondsToSelector:@selector(coreDataSourceWillChangeContent:)]) {
        [self.delegate coreDataSourceWillChangeContent:self];
    }
}

- (void)controller:(NSFetchedResultsController *)controller didChangeObject:(id)anObject
       atIndexPath:(NSIndexPath *)indexPath forChangeType:(NSFetchedResultsChangeType)type
      newIndexPath:(NSIndexPath *)newIndexPath {
    
    SPASLogDetail(@"didChangeObject: %@; indexPath: %@; newIndexPath; %@", anObject, indexPath, newIndexPath);
    
    switch(type) {
        case NSFetchedResultsChangeInsert:
            if ([self.delegate respondsToSelector:@selector(coreDataSource:objectWasInserted:)]) {
                [self.delegate coreDataSource:self objectWasInserted:newIndexPath];
            }
            break;
            
        case NSFetchedResultsChangeDelete:
            if ([self.delegate respondsToSelector:@selector(coreDataSource:objectWasDeleted:)]) {
                [self.delegate coreDataSource:self objectWasDeleted:indexPath];
            }
            break;
            
        case NSFetchedResultsChangeUpdate:
            if ([self.delegate respondsToSelector:@selector(coreDataSource:objectWasUpdated:)]) {
                [self.delegate coreDataSource:self objectWasUpdated:indexPath];
            }
            break;
        
        // 5/20/6; Odd. This gets called when an object is updated, sometimes. It may be because the sorting key I'm using in the fetched results controller changed.
        case NSFetchedResultsChangeMove:
            if ([self.delegate respondsToSelector:@selector(coreDataSource:objectWasMovedFrom:to:)]) {
                [self.delegate coreDataSource:self objectWasMovedFrom:indexPath to:newIndexPath];
            }
            break;
    }
}

- (void)controllerDidChangeContent:(NSFetchedResultsController *)controller {
    if ([self.delegate respondsToSelector:@selector(coreDataSourceDidChangeContent:)]) {
        [self.delegate coreDataSourceDidChangeContent:self];
    }
}

- (NSUInteger) numberOfSections;
{
    return [[self.fetchedResultsController sections] count];
}

- (NSUInteger) numberOfRowsInSection: (NSUInteger) section;
{
    AssertIf(section >= self.numberOfSections, @"Yikes: section: Exceeded section count; Have you called fetchData?");
    id <NSFetchedResultsSectionInfo> sectionInfo = [[self.fetchedResultsController sections] objectAtIndex:section];
    NSUInteger count = [sectionInfo numberOfObjects];
    return count;
}

- (NSManagedObject *) objectAtIndexPath: (NSIndexPath *) indexPath;
{
    return [self.fetchedResultsController objectAtIndexPath:indexPath];
}

- (BOOL) fetchData;
{
    self.fetchedResultsController =
        [[NSFetchedResultsController alloc]
            initWithFetchRequest:[self.delegate coreDataSourceFetchRequest:self]
            managedObjectContext:[self.delegate coreDataSourceContext:self]
            sectionNameKeyPath:nil cacheName:nil];
    self.fetchedResultsController.delegate = self;
    
    NSError *error = nil;
    BOOL success = [self.fetchedResultsController performFetch:&error];
    if (! success || error) {
        SPASLogFile(@"Error on NSFetchedResultsController: %@", error);
    }
    
    return success;
}

@end
