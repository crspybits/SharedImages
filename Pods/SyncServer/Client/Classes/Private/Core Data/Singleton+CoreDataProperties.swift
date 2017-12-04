//
//  Singleton+CoreDataProperties.swift
//  Pods
//
//  Created by Christopher Prince on 3/2/17.
//
//

import Foundation
import CoreData


extension Singleton {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Singleton> {
        return NSFetchRequest<Singleton>(entityName: "Singleton");
    }

    @NSManaged public var masterVersion: Int64
    @NSManaged public var pendingSync: UploadQueue?

}
