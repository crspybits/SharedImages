//
//  UploadFileTracker.swift
//  SyncServer
//
//  Created by Christopher Prince on 2/28/17.
//
//  This file was automatically generated and should not be edited.
//

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
    
    var localURL:SMRelativeLocalURL? {
        get {
            if localURLData == nil {
                return nil
            }
            else {
                let url = NSKeyedUnarchiver.unarchiveObject(with: localURLData! as Data) as? SMRelativeLocalURL
                Assert.If(url == nil, thenPrintThisString: "UploadFileTracker: Yikes: No URL!")
                return url
            }
        }
        
        set {
            if newValue == nil {
                localURLData = nil
            }
            else {
                localURLData = NSKeyedArchiver.archivedData(withRootObject: newValue!) as NSData
            }
        }
    }
    
    public class func entityName() -> String {
        return "UploadFileTracker"
    }
    
    public class func newObject() -> NSManagedObject {
        let uft = CoreData.sessionNamed(Constants.coreDataName).newObject(withEntityName: self.entityName()) as! UploadFileTracker
        uft.status = .notStarted
        return uft
    }
}
