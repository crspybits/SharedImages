//
//  UploadQueue.swift
//  SyncServer
//
//  Created by Christopher Prince on 3/2/17.
//
//  This file was automatically generated and should not be edited.
//

import Foundation
import CoreData
import SMCoreLib

@objc(UploadQueue)
public class UploadQueue: NSManagedObject, AllOperations {
    typealias COREDATAOBJECT = UploadQueue

    public class func entityName() -> String {
        return "UploadQueue"
    }
    
    public class func newObject() -> NSManagedObject {
        let uploadQueue = CoreData.sessionNamed(Constants.coreDataName).newObject(withEntityName: self.entityName()) as! UploadQueue
        return uploadQueue
    }
    
    func nextUploadTracker() -> Tracker? {
        let result = uploadTrackers.filter {
            if let uft = $0 as? UploadFileTracker {
                return uft.status == .notStarted
            }
            else if let sgut = $0 as? SharingGroupUploadTracker {
                return sgut.status == .notStarted
            }
            else {
                assert(false)
                return false
            }
        }

        guard result.count > 0 else {
            return nil
        }

        return result[0]
    }
    
    // This is an array of UploadFileTracker's and/or SharingGroupUploadTracker's.
    var uploadTrackers:[Tracker] {
        return uploads!.array as! [Tracker]
    }
    
    var uploadFileTrackers: [UploadFileTracker] {
        return uploadTrackers.filter {$0 is UploadFileTracker} as! [UploadFileTracker]
    }
    
    var sharingGroupUploadTrackers: [SharingGroupUploadTracker] {
        return uploadTrackers.filter {$0 is SharingGroupUploadTracker} as! [SharingGroupUploadTracker]
    }
    
    func remove() {
        CoreData.sessionNamed(Constants.coreDataName).remove(self)
    }
}
