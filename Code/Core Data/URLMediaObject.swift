//
//  URLMediaObject+CoreDataClass.swift
//  SharedImages
//
//  Created by Christopher G Prince on 4/18/19.
//  Copyright © 2019 Spastic Muffin, LLC. All rights reserved.
//
//

import Foundation
import CoreData
import SMCoreLib

@objc(URLMediaObject)
public class URLMediaObject: FileMediaObject, FileMediaObjectProtocol {
    override class func entityName() -> String {
        return "URLMediaObject"
    }
    
    class func newObjectAndMakeUUID(makeUUID: Bool, creationDate:NSDate? = nil) -> NSManagedObject {
        return newObjectAndMakeUUID(entityName: self.entityName(), makeUUID: makeUUID, creationDate:creationDate)
    }
    
    override class func fetchObjectWithUUID(_ uuid:String) -> FileObject? {
        return fetchObjectWithUUID(uuid, entityName: entityName())
    }
    
    override func remove() throws {
        if let previewImage = previewImage {
            try previewImage.remove()
        }
        
        try super.remove()
    }
}
