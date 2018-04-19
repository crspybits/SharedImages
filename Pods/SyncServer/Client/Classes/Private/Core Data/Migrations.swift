//
//  Migrations.swift
//  SyncServer
//
//  Created by Christopher G Prince on 4/16/18.
//

import Foundation
import SMCoreLib

class Migrations {
    static let session = Migrations()
    
    private static let migration1 = SMPersistItemBool(name:"Migrations.migration1", initialBoolValue:false,  persistType: .userDefaults)
    
    private init() {
    }
    
    func run() {
        if !Migrations.migration1.boolValue {
            Migrations.migration1.boolValue = true
            appMetaDataVersionMigration()
        }
    }
    
    // 4/16/18
    private func appMetaDataVersionMigration() {
        CoreData.sessionNamed(Constants.coreDataName).performAndWait() {
            let dirEntries = DirectoryEntry.fetchAll()
            dirEntries.forEach { dirEntry in
                if dirEntry.appMetaData != nil {
                    dirEntry.appMetaDataVersion = 0
                }
            }
            
            CoreData.sessionNamed(Constants.coreDataName).saveContext()
        }
    }
}
