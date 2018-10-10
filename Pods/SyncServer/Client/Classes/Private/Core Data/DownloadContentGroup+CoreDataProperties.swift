//
//  DownloadContentGroup+CoreDataProperties.swift
//  SyncServer
//
//  Created by Christopher G Prince on 8/27/18.
//
//

import Foundation
import CoreData


extension DownloadContentGroup {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<DownloadContentGroup> {
        return NSFetchRequest<DownloadContentGroup>(entityName: "DownloadContentGroup")
    }

    @NSManaged public var fileGroupUUID: String?
    @NSManaged public var sharingGroupUUID: String?
    @NSManaged public var sharingGroupIdInternal: NSNumber?
    @NSManaged public var statusRaw: String?
    @NSManaged public var downloads: NSSet?

}

// MARK: Generated accessors for downloads
extension DownloadContentGroup {

    @objc(addDownloadsObject:)
    @NSManaged public func addToDownloads(_ value: DownloadFileTracker)

    @objc(removeDownloadsObject:)
    @NSManaged public func removeFromDownloads(_ value: DownloadFileTracker)

    @objc(addDownloads:)
    @NSManaged public func addToDownloads(_ values: NSSet)

    @objc(removeDownloads:)
    @NSManaged public func removeFromDownloads(_ values: NSSet)

}
