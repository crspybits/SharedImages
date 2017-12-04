//
//  Uploads.swift
//  SyncServer
//
//  Created by Christopher Prince on 3/2/17.
//
//

import Foundation
import SMCoreLib

extension Upload {
    private class func createNewPendingSync() throws {
        Singleton.get().pendingSync = (UploadQueue.newObject() as! UploadQueue)
        try CoreData.sessionNamed(Constants.coreDataName).context.save()
    }
    
    class func pendingSync() throws -> UploadQueue {
        if Singleton.get().pendingSync == nil {
            try createNewPendingSync()
        }
        
        return Singleton.get().pendingSync!
    }
    
    // Must have uploads in `pendingSync`. This does a `saveContext`.
    class func movePendingSyncToSynced() throws {
        assert(Singleton.get().pendingSync != nil)
        assert(Singleton.get().pendingSync!.uploads!.count > 0)
        
        let uploadQueues = synced()
        uploadQueues.addToQueuesOverride(Singleton.get().pendingSync!)
        
        // This does a `saveContext`, so don't need to do that again.
        try createNewPendingSync()
    }
    
    class func synced() -> UploadQueues {
        return UploadQueues.get()
    }
    
    class func haveSyncQueue() -> Bool {
        return synced().queues!.count > 0
    }
    
    class func getHeadSyncQueue() -> UploadQueue? {
        if !haveSyncQueue()  {
            return nil
        }
        
        return (synced().queues![0] as! UploadQueue)
    }
    
    // There must be a head sync queue.
    class func removeHeadSyncQueue() {
        let head = getHeadSyncQueue()
        assert(head != nil)
        CoreData.sessionNamed(Constants.coreDataName).remove(head!)
    }
}
