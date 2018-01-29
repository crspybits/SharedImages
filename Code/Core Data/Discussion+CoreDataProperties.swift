//
//  Discussion+CoreDataProperties.swift
//  SharedImages
//
//  Created by Christopher G Prince on 1/28/18.
//  Copyright © 2018 Spastic Muffin, LLC. All rights reserved.
//
//

import Foundation
import CoreData


extension Discussion {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Discussion> {
        return NSFetchRequest<Discussion>(entityName: "Discussion")
    }

    @NSManaged public var uuid: String?
    @NSManaged public var urlInternal: NSData?
    @NSManaged public var mimeType: String?
    @NSManaged public var unreadCount: Int32
    @NSManaged public var image: Image?

}
