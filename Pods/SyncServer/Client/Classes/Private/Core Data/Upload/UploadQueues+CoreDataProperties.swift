//
//  UploadQueues+CoreDataProperties.swift
//  Pods
//
//  Created by Christopher Prince on 3/2/17.
//
//

import Foundation
import CoreData


extension UploadQueues {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<UploadQueues> {
        return NSFetchRequest<UploadQueues>(entityName: "UploadQueues");
    }

    @NSManaged public var queues: NSOrderedSet?

}

// MARK: Generated accessors for queues
extension UploadQueues {

    @objc(insertObject:inQueuesAtIndex:)
    @NSManaged public func insertIntoQueues(_ value: UploadQueue, at idx: Int)

    @objc(removeObjectFromQueuesAtIndex:)
    @NSManaged public func removeFromQueues(at idx: Int)

    @objc(insertQueues:atIndexes:)
    @NSManaged public func insertIntoQueues(_ values: [UploadQueue], at indexes: NSIndexSet)

    @objc(removeQueuesAtIndexes:)
    @NSManaged public func removeFromQueues(at indexes: NSIndexSet)

    @objc(replaceObjectInQueuesAtIndex:withObject:)
    @NSManaged public func replaceQueues(at idx: Int, with value: UploadQueue)

    @objc(replaceQueuesAtIndexes:withQueues:)
    @NSManaged public func replaceQueues(at indexes: NSIndexSet, with values: [UploadQueue])

    @objc(addQueuesObject:)
    @NSManaged public func addToQueues(_ value: UploadQueue)

    @objc(removeQueuesObject:)
    @NSManaged public func removeFromQueues(_ value: UploadQueue)

    @objc(addQueues:)
    @NSManaged public func addToQueues(_ values: NSOrderedSet)

    @objc(removeQueues:)
    @NSManaged public func removeFromQueues(_ values: NSOrderedSet)

}
