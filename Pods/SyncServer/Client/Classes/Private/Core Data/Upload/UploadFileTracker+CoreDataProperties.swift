//
//  UploadFileTracker+CoreDataProperties.swift
//  SyncServer
//
//  Created by Christopher G Prince on 2/6/18.
//
//

import Foundation
import CoreData


extension UploadFileTracker {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<UploadFileTracker> {
        return NSFetchRequest<UploadFileTracker>(entityName: "UploadFileTracker")
    }

    @NSManaged public var deleteOnServer: Bool
    @NSManaged public var fileSizeBytes: Int64
    @NSManaged public var localURLData: NSData?
    @NSManaged public var uploadUndeletion: Bool
    @NSManaged public var uploadCopy: Bool
    @NSManaged public var queue: UploadQueue?

}
