//
//  Singleton.swift
//  SyncServer
//
//  Created by Christopher Prince on 3/2/17.
//
//

import Foundation
import CoreData
import SMCoreLib

@objc(Singleton)
public class Singleton: NSManagedObject, CoreDataSingleton, AllOperations {
    typealias COREDATAOBJECT = Singleton
    
    public class func entityName() -> String {
        return "Singleton"
    }
    
    public class func newObject() -> NSManagedObject {
        let singleton = CoreData.sessionNamed(Constants.coreDataName).newObject(withEntityName: self.entityName()) as! Singleton
        singleton.masterVersion = 0
        singleton.nextFileTrackerAge = 0
        return singleton
    }
}
