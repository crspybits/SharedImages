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
    
    var attr: SyncAttributes {
        let mimeType = MimeType(rawValue: self.mimeType!)!
        var attr = SyncAttributes(fileUUID: fileUUID, sharingGroupUUID: sharingGroupUUID!, mimeType: mimeType, creationDate: creationDate! as Date, updateDate: updateDate! as Date)
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
