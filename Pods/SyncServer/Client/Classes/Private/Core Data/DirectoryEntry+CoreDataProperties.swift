//
//  DirectoryEntry+CoreDataProperties.swift
//  SyncServer
//
//  Created by Christopher G Prince on 2/5/18.
//
//

import Foundation
import CoreData


extension DirectoryEntry {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<DirectoryEntry> {
        return NSFetchRequest<DirectoryEntry>(entityName: "DirectoryEntry")
    }

    @NSManaged public var deletedOnServer: Bool
    @NSManaged public var fileUUID: String?
    @NSManaged public var fileVersionInternal: NSNumber?
    @NSManaged public var mimeType: String?
    @NSManaged public var appMetaData: String?

}
