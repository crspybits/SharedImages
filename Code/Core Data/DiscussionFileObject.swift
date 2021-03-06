//
//  DiscussionFileObject.swift
//  SharedImages
//
//  Created by Christopher G Prince on 1/28/18.
//  Copyright © 2018 Spastic Muffin, LLC. All rights reserved.
//
//

// These are called "Discussion" objects, but the underlying file is used for representing discussion comments, and other items-- e.g., the image title.

import Foundation
import CoreData
import SMCoreLib
import SyncServer_Shared

@objc(DiscussionFileObject)
public class DiscussionFileObject: FileObject {
    override class func entityName() -> String {
        return "DiscussionFileObject"
    }

    class func newObjectAndMakeUUID(makeUUID: Bool) -> NSManagedObject {
        let object = CoreData.sessionNamed(CoreDataExtras.sessionName).newObject(withEntityName:
                self.entityName()) as! DiscussionFileObject
        
        if makeUUID {
            object.uuid = UUID.make()
        }
        
        object.unreadCount = 0
        object.readProblem = false
        
        return object
    }
    
    class func newObject() -> NSManagedObject {
        return newObjectAndMakeUUID(makeUUID: false)
    }
    
    class func fetchObjectWithFileGroupUUID(_ fileGroupUUID:String) -> DiscussionFileObject? {
        let managedObject = CoreData.fetchObjectWithUUID(fileGroupUUID, usingUUIDKey: FILE_GROUP_UUID_KEY, fromEntityName: self.entityName(), coreDataSession: CoreData.sessionNamed(CoreDataExtras.sessionName))
        return managedObject as? DiscussionFileObject
    }
    
    static func fetchAll() -> [DiscussionFileObject] {
        var discussions:[DiscussionFileObject]!

        do {
            discussions = try CoreData.sessionNamed(CoreDataExtras.sessionName).fetchAllObjects(
                withEntityName: self.entityName()) as? [DiscussionFileObject]
        } catch (let error) {
            Log.error("Error: \(error)")
            assert(false)
        }
        
        return discussions
    }
    
    static func totalUnreadCount() -> Int {
        let discussions = DiscussionFileObject.fetchAll()
        let result = discussions.reduce(0) { current, discussion in
            return current + discussion.unreadCount
        }
        return Int(result)
    }
}
