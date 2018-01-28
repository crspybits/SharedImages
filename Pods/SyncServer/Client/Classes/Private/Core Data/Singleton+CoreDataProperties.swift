//
//  Singleton+CoreDataProperties.swift
//  SyncServer
//
//  Created by Christopher G Prince on 1/17/18.
//
//

import Foundation
import CoreData


extension Singleton {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Singleton> {
        return NSFetchRequest<Singleton>(entityName: "Singleton")
    }

    @NSManaged public var masterVersion: Int64
    @NSManaged public var nextFileTrackerAge: Int64
    @NSManaged public var pendingSync: UploadQueue?

}
