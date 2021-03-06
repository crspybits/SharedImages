//
//  URLPreviewImageObject+CoreDataClass.swift
//  SharedImages
//
//  Created by Christopher G Prince on 5/4/19.
//  Copyright © 2019 Spastic Muffin, LLC. All rights reserved.
//
//

import Foundation
import CoreData
import SMCoreLib

@objc(URLPreviewImageObject)
public class URLPreviewImageObject: FileObject {
    override class func entityName() -> String {
        return "URLPreviewImageObject"
    }
    
    class func newObjectAndMakeUUID(makeUUID: Bool) -> NSManagedObject {
        let previewImage = CoreData.sessionNamed(CoreDataExtras.sessionName).newObject(withEntityName:
                self.entityName()) as! URLPreviewImageObject
        
        if makeUUID {
            previewImage.uuid = UUID.make()
        }
        
        previewImage.readProblem = false
        
        return previewImage
    }
    
    class func fetchObjectWithFileGroupUUID(_ fileGroupUUID:String) -> URLPreviewImageObject? {
        let managedObject = CoreData.fetchObjectWithUUID(fileGroupUUID, usingUUIDKey: FILE_GROUP_UUID_KEY, fromEntityName: self.entityName(), coreDataSession: CoreData.sessionNamed(CoreDataExtras.sessionName))
        return managedObject as? URLPreviewImageObject
    }
}
