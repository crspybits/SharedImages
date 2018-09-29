//
//  SharingEntry+CoreDataProperties.swift
//  SyncServer
//
//  Created by Christopher G Prince on 9/16/18.
//
//

import Foundation
import CoreData


extension SharingEntry {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<SharingEntry> {
        return NSFetchRequest<SharingEntry>(entityName: "SharingEntry")
    }

    @NSManaged public var removedFromGroup: Bool
    @NSManaged public var masterVersion: Int64
    @NSManaged public var sharingGroupName: String?
    @NSManaged public var sharingGroupUUID: String?

}
