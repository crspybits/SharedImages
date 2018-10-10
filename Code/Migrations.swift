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
    private static let v0_17_4 = SMPersistItemBool(name: "Migrations.v0_17_4", initialBoolValue: false, persistType: .userDefaults)
    
    private init() {
    }
    
    // Run this near or at the very end of the launch sequence in the app delegate-- so all of the setup is done.
    func launch() {
        if !Migrations.v0_17_4.boolValue {
            Migrations.v0_17_4.boolValue = true
            toSharingGroupUUIDs()
        }
    }

    private func toSharingGroupUUIDs() {
        var fromIds:[Int64: String] = [:]
        
        let images = Image.fetchAll()
        var numberImagesWithoutIds = 0
        var numberImagesWithoutUUIDs = 0

        for image in images {
            if let sharingGroupId = image.sharingGroupId {
                if let uuid = fromIds[sharingGroupId] {
                    image.sharingGroupUUID = uuid
                }
                else {
                    numberImagesWithoutUUIDs += 1
                }
            }
            else {
                numberImagesWithoutIds += 1
            }
        }
        
        CoreData.sessionNamed(CoreDataExtras.sessionName).saveContext()
        
        let discussions = Discussion.fetchAll()
        var numberDiscussionsWithoutIds = 0
        var numberDiscussionsWithoutUUIDs = 0
        
        for discussion in discussions {
            if let sharingGroupId = discussion.sharingGroupId {
                if let uuid = fromIds[sharingGroupId] {
                    discussion.sharingGroupUUID = uuid
                }
                else {
                    numberDiscussionsWithoutUUIDs += 1
                }
            }
            else {
                numberDiscussionsWithoutIds += 1
            }
        }

        CoreData.sessionNamed(CoreDataExtras.sessionName).saveContext()
        
        if numberDiscussionsWithoutUUIDs > 0 || numberDiscussionsWithoutIds > 0 || numberImagesWithoutIds > 0 || numberImagesWithoutUUIDs > 0 {
            let message = "numberDiscussionsWithoutUUIDs: \(numberDiscussionsWithoutUUIDs); numberDiscussionsWithoutIds: \(numberDiscussionsWithoutIds); numberImagesWithoutIds: \(numberImagesWithoutIds); numberImagesWithoutUUIDs: \(numberImagesWithoutUUIDs)"
            Log.error(message)
            SMCoreLib.Alert.show(withTitle: "Problem with mapping sharing group ids to UUIDs", message: message)
        }
    }
}
