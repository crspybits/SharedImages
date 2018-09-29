//
//  FileTracker+CoreDataProperties.swift
//  SyncServer
//
//  Created by Christopher G Prince on 9/3/18.
//
//

import Foundation
import CoreData


extension FileTracker {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<FileTracker> {
        return NSFetchRequest<FileTracker>(entityName: "FileTracker")
    }

    @NSManaged public var age: Int64
    @NSManaged public var appMetaData: String?
    @NSManaged public var appMetaDataVersionInternal: NSNumber?
    @NSManaged public var fileGroupUUID: String?
    @NSManaged public var fileUUIDInternal: String?
    @NSManaged public var fileVersionInternal: NSNumber?
    @NSManaged public var localURLData: NSData?
    @NSManaged public var mimeType: String?
    @NSManaged public var sharingGroupIdInternal: NSNumber?

}
