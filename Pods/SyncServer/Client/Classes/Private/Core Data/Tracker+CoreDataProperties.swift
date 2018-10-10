//
//  Tracker+CoreDataProperties.swift
//  SyncServer
//
//  Created by Christopher G Prince on 9/3/18.
//
//

import Foundation
import CoreData


extension Tracker {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Tracker> {
        return NSFetchRequest<Tracker>(entityName: "Tracker")
    }

    @NSManaged public var operationInternal: String?
    @NSManaged public var statusRaw: String?
    @NSManaged public var sharingGroupUUID: String?
    @NSManaged public var queue: UploadQueue?

}
