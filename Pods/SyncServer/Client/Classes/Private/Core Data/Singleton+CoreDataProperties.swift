//
//  Singleton+CoreDataProperties.swift
//  SyncServer
//
//  Created by Christopher G Prince on 9/4/18.
//
//

import Foundation
import CoreData


extension Singleton {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Singleton> {
        return NSFetchRequest<Singleton>(entityName: "Singleton")
    }

    @NSManaged public var nextFileTrackerAge: Int64
    @NSManaged public var pendingSync: UploadQueue?

}
