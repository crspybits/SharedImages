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
    
    private static let migration2 = SMPersistItemBool(name:"biz.SpasticMuffin.SyncServer.Migrations.migration2", initialBoolValue:false,  persistType: .userDefaults)
    
    // 7/28/18; Migration to sharing group ids-- server version 0.16.3
    private static let migration_0_16_3 = SMPersistItemBool(name:
        "biz.SpasticMuffin.SyncServer.Migrations.migration_0_16_3", initialBoolValue:false,  persistType: .userDefaults)
    
    private static let migration_0_17_3 = SMPersistItemBool(name:
        "biz.SpasticMuffin.SyncServer.Migrations.migration_0_17_3", initialBoolValue:false,  persistType: .userDefaults)

    private init() {
    }
    
    func run() {
        if !Migrations.migration_0_17_3.boolValue {
            Migrations.migration_0_17_3.boolValue = true
            migrationToSharingGroupUUIDs()
        }
    }
    
    // Map from sharing group id's to sharing group UUID's.
    func migrationToSharingGroupUUIDs() {
        var numErrors = 0
        
        let lookup:[Int64: String] = [
            1: "DB1DECB5-F2D6-441E-8D6A-4A6AF93216DB",
            2: "61944E02-E76E-4937-8FE6-8BDF6F2D983E",
            3: "1D12B154-A9EB-4B63-AC85-E4BB83DD680D"
        ]
        
        CoreDataSync.perform(sessionName: Constants.coreDataName) {
            let dirEntries = DirectoryEntry.fetchAll()
            for dirEntry in dirEntries {
                guard let sharingGroupId = dirEntry.sharingGroupId else {
                    numErrors += 1
                    Log.error("Directory entry didn't have a sharing group id!")
                    continue
                }
                
                guard let sharingGroupUUID = lookup[sharingGroupId] else {
                    numErrors += 1
                    Log.error("Couldn't get uuid for sharingGroupId: \(sharingGroupId)")
                    continue
                }
                
                dirEntry.sharingGroupUUID = sharingGroupUUID
            }
            
            do {
                try CoreData.sessionNamed(Constants.coreDataName).context.save()
            } catch (let error) {
                numErrors += 1
                Log.error("\(error)")
            }
        }
        
        do {
            try SyncServer.session.reset(type: .tracking)
        } catch (let error) {
            numErrors += 1
            Log.error("\(error)")
        }
        
        if numErrors > 0 {
            Alert.show(withTitle: "Error doing migration", message: "From sharing group id's to UUIDs: Errors: \(numErrors)")
        }
    }
}
