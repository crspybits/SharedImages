//
//  NetworkCached+CoreDataClass.swift
//  SyncServer
//
//  Created by Christopher G Prince on 12/31/17.
//
//

import Foundation
import CoreData
import SMCoreLib
import SyncServer_Shared

@objc(NetworkCached)
public class NetworkCached: NSManagedObject, CoreDataModel, AllOperations, LocalURLData {
    typealias COREDATAOBJECT = NetworkCached
    
    // The full "key" of a NetworkCached object is: a) version, b) uuid, and c) the presence or absence of the downloadURL.
    // I.e., we can have two NetworkCached objects with the same version and uuid-- one can have a downloadURL and the other must have that property set to nil.
    
    static let versionKey = "fileVersion"
    static let uuidKey = "fileUUID"
    
    static let serverURLKeyKey = "serverURLKey"
    static let dateTimeCachedKey = "dateTimeCached"
    
    public class func entityName() -> String {
        return "NetworkCached"
    }
    
    var localURLData: NSData? {
        get {
            return localDownloadURLData
        }
        set {
            localDownloadURLData = newValue
        }
    }
    
    // A non-nil value here indicates this is a download. Otherwise, it's an upload.
    var downloadURL:SMRelativeLocalURL? {
        get {
            return getLocalURLData()
        }
        
        set {
            setLocalURLData(newValue: newValue)
        }
    }
    
    var httpResponse: HTTPURLResponse? {
        get {
            guard let httpResponseData = httpResponseData as Data?,
                let response = NSKeyedUnarchiver.unarchiveObject(with: httpResponseData) as? HTTPURLResponse else {
                return nil
            }
            return response
        }
        
        set {
            httpResponseData = NSKeyedArchiver.archivedData(withRootObject: newValue as Any) as NSData
        }
    }
    
    public class func newObject() -> NSManagedObject {
        let networkCached = CoreData.sessionNamed(Constants.coreDataName).newObject(withEntityName: self.entityName()) as! NetworkCached
        
        // Add a date here. We'll update this when we actually cache the result, but add it here just in case we get objects that are never updated. We'll want to flush those for sure-- and the date will let us do that.
        networkCached.dateTimeCached = Date() as NSDate
        
        return networkCached
    }
    
    public class func fetchObjects(usingPredicate predicate:NSPredicate, onlyOneObjectExpected: Bool = true) -> [NetworkCached]? {
        var objs:[NetworkCached]?
        
        do {
            let result = try CoreData.sessionNamed(Constants.coreDataName)
                .fetchObjects(withEntityName: entityName()) { (request: NSFetchRequest!) in
                request.predicate = predicate
            }
            
            objs = result as? [NetworkCached]
            
        } catch (let error) {
            Log.msg("\(error)")
        }
        
        if nil != objs && onlyOneObjectExpected {
            if objs!.count > 1 {
                Log.error("fetchObjects: There is more than one object matching the predicate, but only one was expected: \(predicate); objs!.count = \(objs!.count)")
                objs = nil
            }
        }
        
        return objs
    }
    
    public class func fetchObjectWithServerURLKey(_ serverURLKey: String) -> NetworkCached? {
        let predicate = NSPredicate(format: "(%K == %@)", serverURLKeyKey, serverURLKey)
        
        if let objs = fetchObjects(usingPredicate: predicate), objs.count == 1 {
            return objs[0]
        }
        else {
            return nil
        }
    }
    
    public class func fetchObjectWithUUID(_ uuid:String, andVersion version:FileVersionInt, download:Bool) -> NetworkCached? {
        
        // Note the use of %i for the Int32 version.
        let predicate = NSPredicate(format: "(%K == %@) AND (%K == %i)", uuidKey, uuid, versionKey, version)
        
        guard var objs = fetchObjects(usingPredicate: predicate, onlyOneObjectExpected: false) else {
            return nil
        }
        
        if download {
            objs = objs.filter({$0.downloadURL != nil})
        }
        else {
            objs = objs.filter({$0.downloadURL == nil})
        }
        
        if objs.count == 1 {
            return objs[0]
        }
        else if objs.count > 1 {
            Log.error("fetchObjectWithUUID: There is more than one object matching the predicate, but only one was expected: \(predicate); objs.count = \(objs.count)")
            return nil
        }
        else {
            return nil
        }
    }
    
    static let staleNumberOfDays = 5
    class func fetchOldCacheEntries(staleNumberOfDays:Int = staleNumberOfDays) -> [NetworkCached]? {
    
        let staleDate = NSCalendar.current.date(byAdding: .day, value: -staleNumberOfDays, to: Date())!
        
        let predicate = NSPredicate(format: "%K <= %@", NetworkCached.dateTimeCachedKey, staleDate as NSDate)
        
        let result = fetchObjects(usingPredicate: predicate, onlyOneObjectExpected: false)
        return result
    }
    
    class func deleteOldCacheEntries() {
        if let entries = fetchOldCacheEntries() {
            for entry in entries {
                CoreData.sessionNamed(Constants.coreDataName).remove(entry)
            }
            CoreData.sessionNamed(Constants.coreDataName).saveContext()
        }
    }
}
