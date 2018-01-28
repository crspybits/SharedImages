//
//  DownloadFileTracker+CoreDataProperties.swift
//  SyncServer
//
//  Created by Christopher G Prince on 1/21/18.
//
//

import Foundation
import CoreData


extension DownloadFileTracker {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<DownloadFileTracker> {
        return NSFetchRequest<DownloadFileTracker>(entityName: "DownloadFileTracker")
    }

    @NSManaged public var creationDate: NSDate?
    @NSManaged public var deletedOnServer: Bool
    @NSManaged public var updateDate: NSDate?

}
