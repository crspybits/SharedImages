//
//  URLMediaObject+CoreDataProperties.swift
//  SharedImages
//
//  Created by Christopher G Prince on 5/4/19.
//  Copyright © 2019 Spastic Muffin, LLC. All rights reserved.
//
//

import Foundation
import CoreData


extension URLMediaObject {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<URLMediaObject> {
        return NSFetchRequest<URLMediaObject>(entityName: "URLMediaObject")
    }

    @NSManaged public var previewImage: URLPreviewImageObject?

}
