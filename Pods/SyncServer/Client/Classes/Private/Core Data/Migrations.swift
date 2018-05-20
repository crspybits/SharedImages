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

    private init() {
    }
    
    func run() {
        // 5/15/18; Remove this migration after it is used by my three users :).
        
        if !Migrations.migration2.boolValue {
            Migrations.migration2.boolValue = true
            v0_15_2()
        }
    }
    
    private func v0_15_2() {
        /*
        DownloadFileTrackers now have url's-- used to be only in UploadFileTracker's -- but generalized this to put in FileTracker's.
        Remove any existing DownloadFileTrackers. This is because I'm now moving to groups of DownloadFileTrackers.
        deletedLocally is now what deletedOnServer used to be. Need to create my own migration.
        */

        do {
            try SyncServer.session.reset(type: .tracking)
        } catch (let error) {
            Log.error("Problem resetting trackers: \(error)")
        }
        
        CoreData.sessionNamed(Constants.coreDataName).performAndWait {
            let entries = DirectoryEntry.fetchAll()
            entries.forEach { entry in
                entry.deletedLocally = entry.deletedOnServer
            }
            
            CoreData.sessionNamed(Constants.coreDataName).saveContext()
        }
    }
}
