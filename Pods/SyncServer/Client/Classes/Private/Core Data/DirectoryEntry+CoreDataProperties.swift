//
//  DirectoryEntry+CoreDataProperties.swift
//  SyncServer
//
//  Created by Christopher G Prince on 7/22/18.
//
//

import Foundation
import CoreData


extension DirectoryEntry {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<DirectoryEntry> {
        return NSFetchRequest<DirectoryEntry>(entityName: "DirectoryEntry")
    }

    @NSManaged public var appMetaData: String?
    @NSManaged public var appMetaDataVersionInternal: NSNumber?
    @NSManaged public var deletedLocallyInternal: Bool
    @NSManaged public var deletedOnServer: Bool
    @NSManaged public var fileGroupUUID: String?
    @NSManaged public var fileUUID: String?
    @NSManaged public var fileVersionInternal: NSNumber?
    @NSManaged public var mimeType: String?
    @NSManaged public var sharingGroupIdInternal: NSNumber?

}
