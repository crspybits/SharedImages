//
//  DirectoryEntry+CoreDataProperties.swift
//  Pods
//
//  Created by Christopher Prince on 3/5/17.
//
//

import Foundation
import CoreData


extension DirectoryEntry {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<DirectoryEntry> {
        return NSFetchRequest<DirectoryEntry>(entityName: "DirectoryEntry");
    }

    @NSManaged public var deletedOnServer: Bool
    @NSManaged public var fileUUID: String?
    @NSManaged public var fileVersionInternal: NSNumber?
    @NSManaged public var mimeType: String?

}
