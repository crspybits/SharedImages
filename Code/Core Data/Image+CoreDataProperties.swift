//
//  Image+CoreDataProperties.swift
//  SharedImages
//
//  Created by Christopher Prince on 6/6/17.
//  Copyright © 2017 Spastic Muffin, LLC. All rights reserved.
//

import Foundation
import CoreData


extension Image {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Image> {
        return NSFetchRequest<Image>(entityName: "Image")
    }

    @NSManaged public var creationDate: NSDate?
    @NSManaged public var mimeType: String?
    @NSManaged public var originalHeight: Float
    @NSManaged public var originalWidth: Float
    @NSManaged public var title: String?
    @NSManaged public var urlInternal: NSData?
    @NSManaged public var uuid: String?

}
