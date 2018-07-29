//
//  Discussion+CoreDataClass.swift
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

@objc(Discussion)
public class Discussion: NSManagedObject {
    static let UUID_KEY = "uuid"
    static let FILE_GROUP_UUID_KEY = "fileGroupUUID"
    
    public var sharingGroupId: SharingGroupId? {
        get {
            return sharingGroupIdInternal?.int64Value
        }
        
        set {
            sharingGroupIdInternal = newValue == nil ? nil : NSNumber(value: newValue!)
        }
    }

    var url:SMRelativeLocalURL? {
        get {
            return CoreData.getSMRelativeLocalURL(fromCoreDataProperty: urlInternal as Data?)
        }
        
        set {
            if newValue == nil {
                urlInternal = nil
            }
            else {
                urlInternal = NSKeyedArchiver.archivedData(withRootObject: newValue!) as NSData?
            }
        }
    }
    
    class func entityName() -> String {
        return "Discussion"
    }

    class func newObjectAndMakeUUID(makeUUID: Bool) -> NSManagedObject {
        let discussion = CoreData.sessionNamed(CoreDataExtras.sessionName).newObject(withEntityName:
                self.entityName()) as! Discussion
        
        if makeUUID {
            discussion.uuid = UUID.make()
        }
        
        discussion.unreadCount = 0
        
        return discussion
    }
    
    class func newObject() -> NSManagedObject {
        return newObjectAndMakeUUID(makeUUID: false)
    }

    class func fetchObjectWithUUID(_ uuid:String) -> Discussion? {
        let managedObject = CoreData.fetchObjectWithUUID(uuid, usingUUIDKey: UUID_KEY, fromEntityName: self.entityName(), coreDataSession: CoreData.sessionNamed(CoreDataExtras.sessionName))
        return managedObject as? Discussion
    }
    
    class func fetchObjectWithFileGroupUUID(_ fileGroupUUID:String) -> Discussion? {
        let managedObject = CoreData.fetchObjectWithUUID(fileGroupUUID, usingUUIDKey: FILE_GROUP_UUID_KEY, fromEntityName: self.entityName(), coreDataSession: CoreData.sessionNamed(CoreDataExtras.sessionName))
        return managedObject as? Discussion
    }
    
    static func fetchAll() -> [Discussion] {
        var discussions:[Discussion]!

        do {
            discussions = try CoreData.sessionNamed(CoreDataExtras.sessionName).fetchAllObjects(
                withEntityName: self.entityName()) as? [Discussion]
        } catch (let error) {
            Log.error("Error: \(error)")
            assert(false)
        }
        
        return discussions
    }
    
    static func totalUnreadCount() -> Int {
        let discussions = Discussion.fetchAll()
        let result = discussions.reduce(0) { current, discussion in
            return current + discussion.unreadCount
        }
        return Int(result)
    }
    
    func remove() throws {
        if let url = url {
            try FileManager.default.removeItem(at: url as URL)
        }
        
        CoreData.sessionNamed(CoreDataExtras.sessionName).remove(self)
    }
    
    func save() {
        CoreData.sessionNamed(CoreDataExtras.sessionName).saveContext()
    }
}
