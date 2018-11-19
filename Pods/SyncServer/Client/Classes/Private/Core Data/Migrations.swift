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
    }
}
