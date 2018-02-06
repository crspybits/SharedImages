//
//  Discussion+CoreDataClass.swift
//  SharedImages
//
//  Created by Christopher G Prince on 1/28/18.
//  Copyright © 2018 Spastic Muffin, LLC. All rights reserved.
//
//

import Foundation
import CoreData
import SMCoreLib

@objc(Discussion)
public class Discussion: NSManagedObject {
    static let UUID_KEY = "uuid"

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
        let discussion = CoreData.sessionNamed(CoreDataExtras.sessionName).newObject(withEntityName: self.entityName()) as! Discussion
        
        if makeUUID {
            discussion.uuid = UUID.make()
        }
        
        discussion.unreadCount = 0
        
        return discussion
    }
    
    class func newObject() -> NSManagedObject {
        return newObjectAndMakeUUID(makeUUID: false)
    }

    class func fetchObjectWithUUID(uuid:String) -> Discussion? {
        let managedObject = CoreData.fetchObjectWithUUID(uuid, usingUUIDKey: UUID_KEY, fromEntityName: self.entityName(), coreDataSession: CoreData.sessionNamed(CoreDataExtras.sessionName))
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
