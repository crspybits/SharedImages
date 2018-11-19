//
//  DownloadFileTracker+CoreDataProperties.swift
//  SyncServer
//
//  Created by Christopher G Prince on 11/17/18.
//
//

import Foundation
import CoreData


extension DownloadFileTracker {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<DownloadFileTracker> {
        return NSFetchRequest<DownloadFileTracker>(entityName: "DownloadFileTracker")
    }

    @NSManaged public var cloudStorageTypeInternal: String?
    @NSManaged public var contentsChangedOnServer: Bool
    @NSManaged public var creationDate: NSDate?
    @NSManaged public var updateDate: NSDate?
    @NSManaged public var group: DownloadContentGroup?

}
