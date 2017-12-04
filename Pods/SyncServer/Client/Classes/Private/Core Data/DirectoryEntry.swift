//
//  DirectoryEntry.swift
//  Pods
//
//  Created by Christopher Prince on 2/24/17.
//
//

import Foundation
import CoreData
import SMCoreLib
import SyncServer_Shared

@objc(DirectoryEntry)
public class DirectoryEntry: NSManagedObject, CoreDataModel, AllOperations {
    typealias COREDATAOBJECT = DirectoryEntry

    public static let UUID_KEY = "fileUUID"
    
    // File's don't get updated with their version until an upload or download occurs. This means that when a DirectoryEntry is created for an upload of a new file, the fileVersion is initially nil.
    public var fileVersion:FileVersionInt? {
        get {
            return fileVersionInternal?.int32Value
        }
        
        set {
            fileVersionInternal = newValue == nil ? nil : NSNumber(value: newValue!)
        }
    }
    
    public class func entityName() -> String {
        return "DirectoryEntry"
    }
    
    public class func newObject() -> NSManagedObject {
        let directoryEntry = CoreData.sessionNamed(Constants.coreDataName).newObject(withEntityName: self.entityName()) as! DirectoryEntry
        directoryEntry.deletedOnServer = false
        return directoryEntry
    }
    
    class func fetchObjectWithUUID(uuid:String) -> DirectoryEntry? {
        let managedObject = CoreData.fetchObjectWithUUID(uuid, usingUUIDKey: UUID_KEY, fromEntityName: self.entityName(), coreDataSession: CoreData.sessionNamed(Constants.coreDataName))
        return managedObject as? DirectoryEntry
    }
}
