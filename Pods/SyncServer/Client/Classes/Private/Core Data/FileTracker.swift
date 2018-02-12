//
//  FileTracker+CoreDataClass.swift
//  Pods
//
//  Created by Christopher Prince on 3/2/17.
//
//

import Foundation
import CoreData
import SMCoreLib
import SyncServer_Shared

@objc(FileTracker)
public class FileTracker: NSManagedObject, Filenaming, FileUUID {
    // FileTracker age keeps track of relative age -- larger numbers mean they were created later in time.
    
    public var fileUUID:String! {
        get {
            return fileUUIDInternal!
        }
        
        set {
            fileUUIDInternal = newValue
        }
    }
    
    public var fileVersion:Int32! {
        get {
            return fileVersionInternal
        }
        
        set {
            fileVersionInternal = newValue
        }
    }
    
    // Only call this when creating an object.
    // 1/28/18; I used to have this in the Singleton itself, but ran into a really odd infinite loop.
    public func addAge() {
        let singleton = Singleton.get()
        Synchronized.block(singleton) {
            age = singleton.nextFileTrackerAge
            singleton.nextFileTrackerAge += 1
        }
    }
}
