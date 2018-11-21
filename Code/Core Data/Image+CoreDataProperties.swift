//
//  Image+CoreDataProperties.swift
//  SharedImages
//
//  Created by Christopher G Prince on 11/20/18.
//  Copyright © 2018 Spastic Muffin, LLC. All rights reserved.
//
//

import Foundation
import CoreData


extension Image {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Image> {
        return NSFetchRequest<Image>(entityName: "Image")
    }

    @NSManaged public var creationDate: NSDate?
    @NSManaged public var discussionUUID: String?
    @NSManaged public var fileGroupUUID: String?
    @NSManaged public var mimeType: String?
    @NSManaged public var originalHeight: Float
    @NSManaged public var originalWidth: Float
    @NSManaged public var sharingGroupUUID: String?
    @NSManaged public var title: String?
    @NSManaged public var urlInternal: NSData?
    @NSManaged public var uuid: String?
    @NSManaged public var goneReasonInternal: String?
    @NSManaged public var readProblem: Bool
    @NSManaged public var discussion: Discussion?

}
