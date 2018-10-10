//
//  UploadQueues.swift
//  SyncServer
//
//  Created by Christopher Prince on 3/2/17.
//
//  This file was automatically generated and should not be edited.
//

import Foundation
import CoreData
import SMCoreLib

@objc(UploadQueues)
public class UploadQueues: NSManagedObject, CoreDataSingleton, AllOperations {
    typealias COREDATAOBJECT = UploadQueues
    
    public class func entityName() -> String {
        return "UploadQueues"
    }
    
    public class func newObject() -> NSManagedObject {
        let uploadQueues = CoreData.sessionNamed(Constants.coreDataName).newObject(withEntityName: self.entityName()) as! UploadQueues
        return uploadQueues
    }
}
