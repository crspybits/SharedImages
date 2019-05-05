//
//  URLPreviewImageObject+CoreDataProperties.swift
//  SharedImages
//
//  Created by Christopher G Prince on 5/4/19.
//  Copyright © 2019 Spastic Muffin, LLC. All rights reserved.
//
//

import Foundation
import CoreData


extension URLPreviewImageObject {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<URLPreviewImageObject> {
        return NSFetchRequest<URLPreviewImageObject>(entityName: "URLPreviewImageObject")
    }

    @NSManaged public var urlMedia: URLMediaObject?

}
