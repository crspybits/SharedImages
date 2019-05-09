//
//  FileObject+CoreDataClass.swift
//  SharedImages
//
//  Created by Christopher G Prince on 4/18/19.
//  Copyright © 2019 Spastic Muffin, LLC. All rights reserved.
//
//

import Foundation
import CoreData
import SMCoreLib
import SyncServer_Shared

@objc(FileObject)
public class FileObject: NSManagedObject {
    static let UUID_KEY = "uuid"
    static let FILE_GROUP_UUID_KEY = "fileGroupUUID"
    
    class func entityName() -> String {
        return "FileObject"
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
    
    var gone:GoneReason? {
        get {
            if let goneReasonInternal = goneReasonInternal {
                return GoneReason(rawValue: goneReasonInternal)
            }
            else {
                return nil
            }
        }
        
        set {
            goneReasonInternal = newValue?.rawValue
        }
    }
    
    var hasError: Bool {
        return gone != nil || readProblem
    }
    
    static func fetchAllObjects(entityName: String) -> [FileObject] {
        var fileObjects:[FileObject]!

        do {
            fileObjects = try CoreData.sessionNamed(CoreDataExtras.sessionName).fetchAllObjects(
                withEntityName: entityName) as? [FileObject]
        } catch (let error) {
            Log.error("Error: \(error)")
            assert(false)
        }
        
        return fileObjects
    }
    
    static func fetchAllObjects() -> [FileObject] {
        return fetchAllObjects(entityName: self.entityName())
    }
    
    class func fetchObjectWithUUID(_ uuid:String, entityName: String) -> FileObject? {
        let managedObject = CoreData.fetchObjectWithUUID(uuid, usingUUIDKey: UUID_KEY, fromEntityName: entityName, coreDataSession: CoreData.sessionNamed(CoreDataExtras.sessionName))
        return managedObject as? FileObject
    }
    
    class func fetchObjectWithUUID(_ uuid:String) -> FileObject? {
        return fetchObjectWithUUID(uuid, entityName: entityName())
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
