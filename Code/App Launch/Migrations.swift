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
    
//    private static let migration1 = SMPersistItemInt(name:"Migrations.migration1", initialIntValue:0,  persistType: .userDefaults)
//    private static let coreDataMigration_v0_16_3 = SMPersistItemBool(name: "Migrations.coreDataMigration_v0_16_3", initialBoolValue: false, persistType: .userDefaults)
//    private static let signOutMigration_v0_16_3 = SMPersistItemBool(name: "Migrations.signOutMigration_v0_16_3", initialBoolValue: false, persistType: .userDefaults)
//    private static let v0_17_4 = SMPersistItemBool(name: "Migrations.v0_17_4", initialBoolValue: false, persistType: .userDefaults)

    private static let v0_18_3 = SMPersistItemBool(name: "Migrations.v0_18_3", initialBoolValue: false, persistType: .userDefaults)
    
    private init() {
    }
    
    // Run this near or at the very end of the launch sequence in the app delegate-- so all of the setup is done.
    func launch() {
        if !Migrations.v0_18_3.boolValue {
            Migrations.v0_18_3.boolValue = true
            
            let discussions = Discussion.fetchAll()
            discussions.forEach { discussion in
                discussion.gone = nil
                discussion.readProblem = false
            }
            
            let images = Image.fetchAll()
            images.forEach { image in
                image.gone = nil
                image.readProblem = false
            }
            
            CoreData.sessionNamed(CoreDataExtras.sessionName).saveContext()
        }
    }
}
