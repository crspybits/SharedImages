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

    private init() {
    }
    
    func run() {
        // 5/15/18; Remove this migration after it is used by my three users :).
        
        if !Migrations.migration2.boolValue {
            Migrations.migration2.boolValue = true
            v0_15_2()
        }
    }
    
    func runAfterSharingGroupSetup() {
        // 7/28/18; Remove this migration after it is used by my three users :).
        
        if !Migrations.migration_0_16_3.boolValue {
            Migrations.migration_0_16_3.boolValue = true
            serverv0_16_3()
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
        
        CoreDataSync.perform(sessionName: Constants.coreDataName) {
            let entries = DirectoryEntry.fetchAll()
            entries.forEach { entry in
                entry.deletedLocally = entry.deletedOnServer
            }
            
            CoreData.sessionNamed(Constants.coreDataName).saveContext()
        }
    }
    
    private func serverv0_16_3() {
        /*
        A) Give all of the Directory Entry's a sharingGroupId.
        B) Give any pending uploads or downloads a sharingGroupId: Download content groups, Upload trackers, Download trackers.
        
         Only have a single sharing group id right now per user, so this simple strategy will work.
        */
        
        guard let sharingGroupIds = SyncServerUser.session.sharingGroupIds, sharingGroupIds.count > 0 else {
            Alert.show(withTitle: "Migration Error!", message: "No sharing group ids-- please contact crspybits.")
            Log.error("No sharing group ids!")
            return
        }
        
        let sharingGroupId = sharingGroupIds[0]
        
        // A)
        CoreDataSync.perform(sessionName: Constants.coreDataName) {
            let entries = DirectoryEntry.fetchAll()
            entries.forEach { entry in
                entry.sharingGroupId = sharingGroupId
            }
            
            CoreData.sessionNamed(Constants.coreDataName).saveContext()
        }
        
        // B)
        
        CoreDataSync.perform(sessionName: Constants.coreDataName) {
            let dcgs = DownloadContentGroup.fetchAll()
            dcgs.forEach { dcg in
                dcg.sharingGroupId = sharingGroupId
            }
            
            CoreData.sessionNamed(Constants.coreDataName).saveContext()
        }
        
        CoreDataSync.perform(sessionName: Constants.coreDataName) {
            let dfts = DownloadFileTracker.fetchAll()
            dfts.forEach { dft in
                dft.sharingGroupId = sharingGroupId
            }
            
            CoreData.sessionNamed(Constants.coreDataName).saveContext()
        }
        
        CoreDataSync.perform(sessionName: Constants.coreDataName) {
            let ufts = UploadFileTracker.fetchAll()
            ufts.forEach { uft in
                uft.sharingGroupId = sharingGroupId
            }
            
            CoreData.sessionNamed(Constants.coreDataName).saveContext()
        }
    }
}
