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
    
    public var appMetaDataVersion: AppMetaDataVersionInt? {
        get {
            return appMetaDataVersionInternal?.int32Value
        }
        
        set {
            appMetaDataVersionInternal = newValue == nil ? nil : NSNumber(value: newValue!)
        }
    }
    
    // Setting this assumes the file has also been deleted on the server.
    public var deletedLocally:Bool {
        get {
            return deletedLocallyInternal
        }
        
        set {
            deletedLocallyInternal = newValue
            deletedOnServer = newValue
        }
    }
    
    // Based on the current directory entry appMetaDataVersion and an update to be made to the appMetaData, establish the appMetaDataVersion to upload with a new file version.
    public func appMetaDataVersionToUpload(appMetaDataUpdate: String?) -> AppMetaDataVersionInt? {
        if appMetaDataUpdate == nil {
            return nil
        }
        else if appMetaDataVersion == nil {
            return 0
        }
        else {
            return appMetaDataVersion! + 1
        }
    }
    
    var cloudStorageType: CloudStorageType? {
        get {
            if let cloudStorageTypeInternal = cloudStorageTypeInternal {
                return CloudStorageType(rawValue: cloudStorageTypeInternal)
            }
            else {
                return nil
            }
        }
        
        set {
            cloudStorageTypeInternal = newValue?.rawValue
        }
    }
    
    var attr: SyncAttributes {
        // 5/19/18; I don't know why this should happen-- but I was getting a nil mimeType in a DirectoryEntry. The following code is so this doesn't cause an explosion.
        var mimeType:MimeType!
        if let rawMimeType = self.mimeType {
            mimeType = MimeType(rawValue: rawMimeType)
        }
        if mimeType == nil {
            mimeType = .unknown
        }
        
        var attr = SyncAttributes(fileUUID: fileUUID!, sharingGroupUUID: sharingGroupUUID!, mimeType: mimeType)
        attr.gone = gone
        attr.appMetaData = appMetaData
        attr.fileGroupUUID = fileGroupUUID
        return attr
    }
    
    // This is in the DirectoryEntry object because we need a way to avoid repeated efforts to download the same gone file. The client app needs to explicitly request a new download attempt for a gone file.
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
    
    public class func entityName() -> String {
        return "DirectoryEntry"
    }
    
    public class func newObject() -> NSManagedObject {
        let directoryEntry = CoreData.sessionNamed(Constants.coreDataName).newObject(withEntityName: self.entityName()) as! DirectoryEntry
        directoryEntry.deletedLocally = false
        directoryEntry.forceDownload = false
        return directoryEntry
    }
    
    class func fetchObjectWithUUID(uuid:String) -> DirectoryEntry? {
        let managedObject = CoreData.fetchObjectWithUUID(uuid, usingUUIDKey: UUID_KEY, fromEntityName: self.entityName(), coreDataSession: CoreData.sessionNamed(Constants.coreDataName))
        return managedObject as? DirectoryEntry
    }
    
    func remove()  {
        CoreData.sessionNamed(Constants.coreDataName).remove(self)
    }
}
