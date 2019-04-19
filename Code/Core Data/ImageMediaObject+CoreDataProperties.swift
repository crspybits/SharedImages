//
//  ImageURLMediaObject+CoreDataProperties.swift
//  SharedImages
//
//  Created by Christopher G Prince on 4/18/19.
//  Copyright © 2019 Spastic Muffin, LLC. All rights reserved.
//
//

import Foundation
import CoreData


extension ImageMediaObject {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<ImageMediaObject> {
        return NSFetchRequest<ImageMediaObject>(entityName: "ImageMediaObject")
    }

    @NSManaged public var originalHeight: Float
    @NSManaged public var originalWidth: Float

}
