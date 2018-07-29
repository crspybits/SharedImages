//
//  Migrations.swift
//  SharedImages
//
//  Created by Christopher G Prince on 5/19/18.
//  Copyright © 2018 Spastic Muffin, LLC. All rights reserved.
//

import Foundation
import SMCoreLib
import SyncServer

class Migrations {
    static let session = Migrations()
    
    private static let migration1 = SMPersistItemInt(name:"Migrations.migration1", initialIntValue:0,  persistType: .userDefaults)

    private static let coreDataMigration_v0_16_3 = SMPersistItemBool(name: "Migrations.coreDataMigration_v0_16_3", initialBoolValue: false, persistType: .userDefaults)
    private static let signOutMigration_v0_16_3 = SMPersistItemBool(name: "Migrations.signOutMigration_v0_16_3", initialBoolValue: false, persistType: .userDefaults)
    
    private init() {
    }
    
    // Run this near or at the very end of the launch sequence in the app delegate-- so all of the setup is done.
    func launch() {
        if !Migrations.signOutMigration_v0_16_3.boolValue {
            Migrations.signOutMigration_v0_16_3.boolValue = true
            signoutMigration_v0_16_3()
        }
    }
    
    func runAfterHaveSharingGroupId() {
        if !Migrations.coreDataMigration_v0_16_3.boolValue {
            Migrations.coreDataMigration_v0_16_3.boolValue = true
            serverv0_16_3()
        }
    }
    
    // We've added file group UUID's to some images-- need to update those locally.
    func v0_15_0(completion:@escaping ()->()) {
        // I've got a hack in here. Not quite sure why I have to do this more than once.
        if Migrations.migration1.intValue >= 3 {
            completion()
            return
        }
        
        Migrations.migration1.intValue += 1
        
        // I'm not quite sure why, but without this async dispatch, when I callback into the SyncServer below, my code blocks-- seems due to the fact that this method is getting called from a SyncServer callback.
        DispatchQueue.main.async {
            let images = Image.fetchAll()
            images.forEach { image in
                do {
                    if image.fileGroupUUID == nil {
                        let attr = try SyncServer.session.getAttributes(forUUID: image.uuid!)
                        Log.msg("attr.fileGroupUUID: \(String(describing: attr.fileGroupUUID))")
                        image.fileGroupUUID = attr.fileGroupUUID
                        
                        if let fileGroupUUID = attr.fileGroupUUID,
                            let discussion = Discussion.fetchObjectWithFileGroupUUID(fileGroupUUID) {
                            discussion.image = image
                        }
                    }
                } catch (let error) {
                    Log.error("v0_15_0: Error: \(error)")
                }
            }
            
            CoreData.sessionNamed(CoreDataExtras.sessionName).saveContext()
            completion()
        }
    }
    
    // 7/28/18; Added sharing group ids.
    private func serverv0_16_3() {
        guard let sharingGroupId = SyncController.getSharingGroupId() else {
            SMCoreLib.Alert.show(withTitle: "Migration Error!", message: "Could not get sharing group id-- please contact crspybits")
            return
        }
        
        let images = Image.fetchAll()
        images.forEach { image in
            image.sharingGroupId = sharingGroupId
        }
    
        CoreData.sessionNamed(CoreDataExtras.sessionName).saveContext()
        
        let discussions = Discussion.fetchAll()
        
        discussions.forEach { discussion in
            discussion.sharingGroupId = sharingGroupId
        }
    
        CoreData.sessionNamed(CoreDataExtras.sessionName).saveContext()
    }
    
    private func signoutMigration_v0_16_3() {
        SignInManager.session.currentSignIn?.signUserOut()
    }
}
