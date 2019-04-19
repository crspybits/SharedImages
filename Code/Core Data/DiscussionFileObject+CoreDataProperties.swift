//
//  DiscussionFileObject+CoreDataProperties.swift
//  SharedImages
//
//  Created by Christopher G Prince on 4/18/19.
//  Copyright © 2019 Spastic Muffin, LLC. All rights reserved.
//
//

import Foundation
import CoreData


extension DiscussionFileObject {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<DiscussionFileObject> {
        return NSFetchRequest<DiscussionFileObject>(entityName: "DiscussionFileObject")
    }

    @NSManaged public var unreadCount: Int32
    @NSManaged public var mediaObject: FileMediaObject?

}
