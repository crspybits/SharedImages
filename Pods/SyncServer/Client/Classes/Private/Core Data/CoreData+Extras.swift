//
//  CoreDataProtocols.swift
//  SyncServer
//
//  Created by Christopher Prince on 3/2/17.
//
//

import Foundation
import SMCoreLib

protocol CoreDataSingleton : CoreDataModel {
    associatedtype COREDATAOBJECT
    static func get() -> COREDATAOBJECT
}

class CoreDataSync {
    // It looks like a dispatch queue can be used to serialize Core Data requests: https://stackoverflow.com/questions/22091696/how-to-dispatch-code-blocks-to-the-same-thread-in-ios
    // The reason I'm doing this is because my needs are not for concurrent access to Core Data. Rather, the SyncServer class (which is directly used by clients) and the internals of the SyncServer (e.g., the SyncManager) each need access to the Core Data objects. And each of these can run on different threads. But, I don't need concurrent access to Core Data. For example, each Core Data access is fairly quick running.
    private static let serialQueue = DispatchQueue(label: "CoreDataSync")
    
    // This is *not* reentrant.
    static func perform(sessionName: String, block: @escaping ()->()) {
        serialQueue.sync {
            CoreData.sessionNamed(sessionName).performAndWait() {
                block()
            }
        }
    }
}

extension CoreDataSingleton {
    static func get() -> COREDATAOBJECT {
        var cdos = [COREDATAOBJECT]()
        var cdo:COREDATAOBJECT?
        
        do {
            let objs = try CoreData.sessionNamed(Constants.coreDataName).fetchAllObjects(withEntityName: self.entityName())
            cdos = objs as! [COREDATAOBJECT]
        } catch (_) {
            assert(false)
        }
        
        if cdos.count == 0 {
            cdo = (self.newObject!() as! COREDATAOBJECT)
        }
        else if cdos.count > 1 {
            assert(false)
        }
        else {
            cdo = cdos[0]
        }
        
        return cdo!
    }
}

protocol AllOperations : CoreDataModel {
    associatedtype COREDATAOBJECT
    static func fetchAll() -> [COREDATAOBJECT]
    static func removeAll()
}

extension AllOperations {
    static func fetchAll() -> [COREDATAOBJECT] {
        var entries:[COREDATAOBJECT]!

        do {
            entries = try CoreData.sessionNamed(Constants.coreDataName).fetchAllObjects(withEntityName: self.entityName()) as? [COREDATAOBJECT]
         } catch (let error) {
            Log.error("Error: \(error)")
            assert(false)
         }
        
         return entries
    }
    
    static func removeAll() {
        do {
            let entries = try CoreData.sessionNamed(Constants.coreDataName).fetchAllObjects(withEntityName: self.entityName())
            
            for entry in entries {
                CoreData.sessionNamed(Constants.coreDataName).remove(entry as! NSManagedObject)
            }            
        } catch (let error) {
            Log.error("Error: \(error)")
            assert(false)
        }
    }
    
    static func printAll() {
        do {
            let entries = try CoreData.sessionNamed(Constants.coreDataName).fetchAllObjects(withEntityName: self.entityName())
            
            Log.msg("Core Data Entity: \(self.entityName()) has \(entries.count) objects.")

            for entry in entries {
                // Fault in object https://stackoverflow.com/questions/14634395/what-is-coredata-faulting so we can print it.
                (entry as! NSManagedObject).willAccessValue(forKey: nil)
                
                Log.msg("\(String(describing: entry))")
            }            
        } catch (let error) {
            Log.error("Error: \(error)")
            assert(false)
        }
    }
    
    func save() {
        CoreData.sessionNamed(Constants.coreDataName).saveContext()
    }
}
