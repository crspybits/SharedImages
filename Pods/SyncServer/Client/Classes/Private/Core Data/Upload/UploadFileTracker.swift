//
//  UploadFileTracker.swift
//  SyncServer
//
//  Created by Christopher Prince on 2/28/17.
//

// For tracking both file uploads and appMetaData uploads (usually termed `content`).

import Foundation
import CoreData
import SMCoreLib

@objc(UploadFileTracker)
public class UploadFileTracker: FileTracker, AllOperations {
    typealias COREDATAOBJECT = UploadFileTracker

    enum Status : String {
    case notStarted
    case uploading
    case uploaded
    }
    
    var status:Status {
        get {
            return Status(rawValue: statusRaw!)!
        }
        
        set {
            statusRaw = newValue.rawValue
        }
    }
    
    public class func entityName() -> String {
        return "UploadFileTracker"
    }
    
    public class func newObject() -> NSManagedObject {
        let uft = CoreData.sessionNamed(Constants.coreDataName).newObject(withEntityName: self.entityName()) as! UploadFileTracker
        uft.status = .notStarted
        uft.addAge()
        uft.uploadUndeletion = false
        return uft
    }
    
    func remove() throws {
        if uploadCopy, let url = localURL {
            try FileManager.default.removeItem(at: url as URL)
        }
        
        CoreData.sessionNamed(Constants.coreDataName).remove(self)
    }
}
