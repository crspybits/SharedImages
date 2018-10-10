//
//  NetworkCached+CoreDataProperties.swift
//  SyncServer
//
//  Created by Christopher G Prince on 1/3/18.
//
//

import Foundation
import CoreData


extension NetworkCached {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<NetworkCached> {
        return NSFetchRequest<NetworkCached>(entityName: "NetworkCached")
    }

    @NSManaged public var fileUUID: String?
    @NSManaged public var fileVersion: Int32
    @NSManaged public var httpResponseData: NSData?
    @NSManaged public var localDownloadURLData: NSData?
    @NSManaged public var serverURLKey: String?
    @NSManaged public var dateTimeCached: NSDate?

}
