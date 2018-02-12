//
//  FileTracker+CoreDataProperties.swift
//  SyncServer
//
//  Created by Christopher G Prince on 2/5/18.
//
//

import Foundation
import CoreData


extension FileTracker {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<FileTracker> {
        return NSFetchRequest<FileTracker>(entityName: "FileTracker")
    }

    @NSManaged public var age: Int64
    @NSManaged public var fileUUIDInternal: String?
    @NSManaged public var fileVersionInternal: Int32
    @NSManaged public var mimeType: String?
    @NSManaged public var statusRaw: String?
    @NSManaged public var appMetaData: String?

}
