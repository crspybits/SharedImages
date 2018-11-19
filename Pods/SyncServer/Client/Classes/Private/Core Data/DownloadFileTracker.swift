//
//  DownloadFileTracker.swift
//  Pods
//
//  Created by Christopher Prince on 2/24/17.
//
//

import Foundation
import CoreData
import SMCoreLib
import SyncServer_Shared

@objc(DownloadFileTracker)
public class DownloadFileTracker: FileTracker, AllOperations {
    typealias COREDATAOBJECT = DownloadFileTracker
    
    enum Status : String {
    case notStarted
    case downloading
    
    // Either the file has been successfully downloaded or the file was "gone".
    case downloaded
    }
    
    var status:Status {
        get {
            return Status(rawValue: statusRaw!)!
        }
        
        set {
            statusRaw = newValue.rawValue
        }
    }
    
    // Storing the cloudStorageType in the DownloadFileTracker so we can populate the DirectoryEntry's with the cloud storage type on a download.
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
        let mimeType = MimeType(rawValue: self.mimeType!)!
        
        var attr:SyncAttributes
        
        if let gone = gone {
            attr = SyncAttributes(fileUUID: fileUUID, sharingGroupUUID: sharingGroupUUID!, mimeType: mimeType, creationDate: nil, updateDate: nil)
            attr.gone = gone
        }
        else {
            attr = SyncAttributes(fileUUID: fileUUID, sharingGroupUUID: sharingGroupUUID!, mimeType: mimeType, creationDate: creationDate! as Date, updateDate: updateDate! as Date)
        }

        attr.appMetaData = appMetaData
        attr.fileGroupUUID = fileGroupUUID
        return attr
    }
    
    public class func entityName() -> String {
        return "DownloadFileTracker"
    }
    
    public class func newObject() -> NSManagedObject {
        let dft = CoreData.sessionNamed(Constants.coreDataName).newObject(withEntityName: self.entityName()) as! DownloadFileTracker
        dft.status = .notStarted
        dft.addAge()
        return dft
    }
    
    func remove()  {
        CoreData.sessionNamed(Constants.coreDataName).remove(self)
    }
}
