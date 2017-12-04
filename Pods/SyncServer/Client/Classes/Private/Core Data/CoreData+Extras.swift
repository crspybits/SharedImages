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
}
