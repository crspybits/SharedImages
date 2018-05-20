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
    
    private static let migration1 = SMPersistItemBool(name:"Migrations.migration1", initialBoolValue:false,  persistType: .userDefaults)

    private init() {
    }
    
    // We've added file group UUID's to some images-- need to update those locally.
    func v0_15_0(completion:@escaping ()->()) {
        if Migrations.migration1.boolValue {
            completion()
            return
        }
        
        Migrations.migration1.boolValue = true
        
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
}
