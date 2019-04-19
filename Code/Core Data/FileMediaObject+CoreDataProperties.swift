//
//  FileMediaObject+CoreDataProperties.swift
//  SharedImages
//
//  Created by Christopher G Prince on 4/18/19.
//  Copyright © 2019 Spastic Muffin, LLC. All rights reserved.
//
//

import Foundation
import CoreData


extension FileMediaObject {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<FileMediaObject> {
        return NSFetchRequest<FileMediaObject>(entityName: "FileMediaObject")
    }

    @NSManaged public var creationDate: NSDate?
    @NSManaged public var discussionUUID: String?
    @NSManaged public var title: String?
    @NSManaged public var discussion: Discussion?

}
