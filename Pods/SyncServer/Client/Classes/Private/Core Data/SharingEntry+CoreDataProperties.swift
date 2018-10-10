//
//  SharingEntry+CoreDataProperties.swift
//  SyncServer
//
//  Created by Christopher G Prince on 10/6/18.
//
//

import Foundation
import CoreData


extension SharingEntry {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<SharingEntry> {
        return NSFetchRequest<SharingEntry>(entityName: "SharingEntry")
    }

    @NSManaged public var masterVersion: Int64
    @NSManaged public var removedFromGroup: Bool
    @NSManaged public var sharingGroupName: String?
    @NSManaged public var sharingGroupUUID: String?
    @NSManaged public var syncNeeded: Bool
    @NSManaged public var permissionInternal: String?

}
