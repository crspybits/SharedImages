//
//  SharingGroupUploadTracker+CoreDataProperties.swift
//  SyncServer
//
//  Created by Christopher G Prince on 9/4/18.
//
//

import Foundation
import CoreData


extension SharingGroupUploadTracker {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<SharingGroupUploadTracker> {
        return NSFetchRequest<SharingGroupUploadTracker>(entityName: "SharingGroupUploadTracker")
    }

    @NSManaged public var sharingGroupOperationInternal: String?
    @NSManaged public var sharingGroupName: String?

}
