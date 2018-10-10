//
//  UploadQueue+CoreDataProperties.swift
//  SyncServer
//
//  Created by Christopher G Prince on 9/3/18.
//
//

import Foundation
import CoreData


extension UploadQueue {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<UploadQueue> {
        return NSFetchRequest<UploadQueue>(entityName: "UploadQueue")
    }

    @NSManaged public var pendingSync: Singleton?
    @NSManaged public var synced: UploadQueues?
    @NSManaged public var uploads: NSOrderedSet?

}

// MARK: Generated accessors for uploads
extension UploadQueue {

    @objc(insertObject:inUploadsAtIndex:)
    @NSManaged public func insertIntoUploads(_ value: Tracker, at idx: Int)

    @objc(removeObjectFromUploadsAtIndex:)
    @NSManaged public func removeFromUploads(at idx: Int)

    @objc(insertUploads:atIndexes:)
    @NSManaged public func insertIntoUploads(_ values: [Tracker], at indexes: NSIndexSet)

    @objc(removeUploadsAtIndexes:)
    @NSManaged public func removeFromUploads(at indexes: NSIndexSet)

    @objc(replaceObjectInUploadsAtIndex:withObject:)
    @NSManaged public func replaceUploads(at idx: Int, with value: Tracker)

    @objc(replaceUploadsAtIndexes:withUploads:)
    @NSManaged public func replaceUploads(at indexes: NSIndexSet, with values: [Tracker])

    @objc(addUploadsObject:)
    @NSManaged public func addToUploads(_ value: Tracker)

    @objc(removeUploadsObject:)
    @NSManaged public func removeFromUploads(_ value: Tracker)

    @objc(addUploads:)
    @NSManaged public func addToUploads(_ values: NSOrderedSet)

    @objc(removeUploads:)
    @NSManaged public func removeFromUploads(_ values: NSOrderedSet)

}
