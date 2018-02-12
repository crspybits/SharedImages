//
//  ConflictManager.swift
//  SyncServer
//
//  Created by Christopher G Prince on 1/17/18.
//

import Foundation
import SyncServer_Shared
import SMCoreLib

class ConflictManager {
    // completion's are called when the client has resolved all conflicts if there are any. If there are no conflicts, the call to the completion is synchronous.
    
    static func handleAnyFileDownloadConflict(attr:SyncAttributes, url: SMRelativeLocalURL, delegate: SyncServerDelegate, completion:@escaping (_ keepThisOne: SyncAttributes?)->()) {
    
        var resolver: SyncServerConflict<FileDownloadResolution>?
        
        CoreData.sessionNamed(Constants.coreDataName).performAndWait() {
            let pendingUploads = UploadFileTracker.fetchAll()
            
            // For this file download we could have (a) an upload deletion conflict, (b) file upload conflict(s), or (c) both an upload deletion conflict and file upload conflict(s).
            
            // Do we have a pending upload deletion that conflicts with the file download? In this case there could be at most a single upload deletion. It's an error for the client to try to queue up more than one deletion (with sync's between them).
            let conflictingUploadDeletions = pendingUploads.filter(
                {$0.deleteOnServer && $0.fileUUID == attr.fileUUID})

            // Do we have pending file upload(s) that conflict with the file download? In this case there could be more than one upload with the same uuid. For example, if the client does a file upload of uuid X, syncs, then another upload of X, and then sync.
            let conflictingFileUploads = pendingUploads.filter(
                {!$0.deleteOnServer && $0.fileUUID == attr.fileUUID})
            
            var conflictType:SyncServerConflict<FileDownloadResolution>.ClientOperation?
            
            if conflictingUploadDeletions.count > 0 && conflictingFileUploads.count > 0 {
                // This can arise when a file was queued for upload, synced, and then queued for deletion and synced
                conflictType = .bothFileUploadAndDeletion
            }
            else if conflictingFileUploads.count > 0 {
                conflictType = .fileUpload
            }
            else if conflictingUploadDeletions.count > 0 {
                conflictType = .uploadDeletion
            }
            
            if let conflictType = conflictType {
                resolver = SyncServerConflict<FileDownloadResolution>(
                    conflictType: conflictType, resolutionCallback: { resolution in
                
                    switch resolution {
                    case .acceptFileDownload:
                        removeManagedObjects(conflictingFileUploads, delegate: delegate)
                        removeManagedObjects(conflictingUploadDeletions, delegate: delegate)
                        completion(nil)
                        
                    case .rejectFileDownload(let uploadResolution):
                        if uploadResolution.removeFileUploads {
                            removeManagedObjects(conflictingFileUploads, delegate: delegate)
                        }
                        
                        if uploadResolution.removeUploadDeletions {
                            removeManagedObjects(conflictingUploadDeletions, delegate: delegate)
                        }
                        
                        completion(attr)
                    }
                })
            }
        }
        
        if let resolver = resolver {
            // See note [1] below re: why I'm not calling this on the main thread.
            delegate.syncServerMustResolveFileDownloadConflict(downloadedFile: url, downloadedFileAttributes: attr, uploadConflict: resolver)
        }
        else {
            completion(nil)
        }
    }
    
    // In the completion, `keepTheseOnes` gives attr's for the files the client doesn't wish to have deleted by the given download deletions.
    static func handleAnyDownloadDeletionConflicts(downloadDeletionAttrs:[SyncAttributes], delegate: SyncServerDelegate,
        completion:@escaping (_ keepTheseOnes: [SyncAttributes], _ havePendingUploadDeletions: [SyncAttributes])->()) {
    
        var remainingDownloadDeletionAttrs = downloadDeletionAttrs
        
        // If we have a pending upload deletion, no worries. Then we have a "conflict" between a download deletion, and an upload deletion. Someone just beat us to it. No need to keep on with our upload deletion.
        // Let's go ahead and remove the pending deletions, if any.
        
        var conflicts = [(downloadDeletion: SyncAttributes, uploadConflict: SyncServerConflict<DownloadDeletionResolution>)]()
        
        // We'll want no deletion delegate callback for these.
        var havePendingUploadDeletions = [SyncAttributes]()
        
        CoreData.sessionNamed(Constants.coreDataName).performAndWait() {
            let pendingUploadDeletions = UploadFileTracker.fetchAll().filter({$0.deleteOnServer})
            
            let pendingDeletionsToRemove = fileUUIDIntersection(pendingUploadDeletions, downloadDeletionAttrs)
            pendingDeletionsToRemove.forEach() { (uft, attr) in
                let fileUUID = uft.fileUUID
                
                do {
                    try uft.remove()
                } catch {
                    delegate.syncServerErrorOccurred(error:
                        .couldNotRemoveFileTracker)
                }
                
                let index = remainingDownloadDeletionAttrs.index(where: {$0.fileUUID == fileUUID})!
                remainingDownloadDeletionAttrs.remove(at: index)
                havePendingUploadDeletions += [attr]
            }
            
            CoreData.sessionNamed(Constants.coreDataName).saveContext()
            
            // Now, let's see if we have pending file uploads conflicting with any of these deletions. This is a prioritization issue. There is a pending download deletion. The client has a pending file upload. The client needs to make a judgement call: Should their upload take priority and upload undelete the file, or should the download deletion be accepted?
            
            let pendingFileUploads = UploadFileTracker.fetchAll().filter({!$0.deleteOnServer})
            let conflictingFileUploads = fileUUIDIntersection(pendingFileUploads, remainingDownloadDeletionAttrs)
            
            if conflictingFileUploads.count > 0 {
                var numberConflicts = conflictingFileUploads.count
                
                var deletionsToIgnore = [SyncAttributes]()
                
                conflictingFileUploads.forEach { (conflictUft, attr) in
                    let resolver = SyncServerConflict<DownloadDeletionResolution>(
                        conflictType: .fileUpload, resolutionCallback: { resolution in
                    
                        switch resolution {
                        case .acceptDownloadDeletion:
                            removeConflictingUpload(pendingFileUploads: pendingFileUploads, fileUUID: attr.fileUUID, delegate: delegate)
                            
                        case .rejectDownloadDeletion(let uploadResolution):
                            // We're going to disregard the download deletion.
                            deletionsToIgnore += [attr]
                            
                            switch uploadResolution {
                            case .keepFileUpload:
                                // Need to mark the uft as an upload undeletion.
                                markUftAsUploadUndeletion(pendingFileUploads: pendingFileUploads, fileUUID: attr.fileUUID)
                                
                            case .removeFileUpload:
                                removeConflictingUpload(pendingFileUploads: pendingFileUploads, fileUUID: attr.fileUUID, delegate: delegate)
                            }
                        }
                        
                        numberConflicts -= 1
                        
                        if numberConflicts == 0 {
                            completion(deletionsToIgnore, havePendingUploadDeletions)
                        }
                    })
                    
                    conflicts += [(attr, resolver)]
                }
            }
        }
        
        if conflicts.count > 0 {
            // See note [1] below re: why I'm not calling this on the main thread.
            delegate.syncServerMustResolveDownloadDeletionConflicts(conflicts: conflicts)
        }
        else {
            completion([], havePendingUploadDeletions)
        }
    }
    
    // Where this gets tricky is what we need is that only the very first uft for this fileUUID needs to be an upload undeletion. i.e., the uft that will get serviced the first.
    private static func markUftAsUploadUndeletion(pendingFileUploads: [UploadFileTracker], fileUUID: String) {
    
        CoreData.sessionNamed(Constants.coreDataName).performAndWait() {
            var toKeep = pendingFileUploads.filter({$0.fileUUID == fileUUID})
            toKeep.sort(by: { (uft1, uft2) -> Bool in
                return uft1.age < uft2.age
            })
            toKeep[0].uploadUndeletion = true
            CoreData.sessionNamed(Constants.coreDataName).saveContext()
        }
    }
    
    // Remove any pending file upload's with this UUID.
    private static func removeConflictingUpload(pendingFileUploads: [UploadFileTracker], fileUUID:String, delegate: SyncServerDelegate) {
        // [1] Having deadlock issue here. Resolving it by documenting that delegate is *not* called on main thread for the two conflict delegate methods. Not the best solution.
        CoreData.sessionNamed(Constants.coreDataName).performAndWait() {
            let toDelete = pendingFileUploads.filter({$0.fileUUID == fileUUID})
            toDelete.forEach { uft in
                do {
                    try uft.remove()
                } catch {
                    delegate.syncServerErrorOccurred(error:
                        .couldNotRemoveFileTracker)
                }
            }

            CoreData.sessionNamed(Constants.coreDataName).saveContext()
        }
    }
    
    private static func removeManagedObjects(_ managedObjects:[NSManagedObject], delegate: SyncServerDelegate) {
        CoreData.sessionNamed(Constants.coreDataName).performAndWait() {
            managedObjects.forEach { managedObject in
                if let uft = managedObject as? UploadFileTracker {
                    do {
                        try uft.remove()
                    } catch {
                        delegate.syncServerErrorOccurred(error:
                            .couldNotRemoveFileTracker)
                    }
                }
                else {
                    CoreData.sessionNamed(Constants.coreDataName).remove(managedObject)
                }
            }
            CoreData.sessionNamed(Constants.coreDataName).saveContext()
        }
    }

    // Returns the pairs: (firstElem, secondElem) where those have matching fileUUID's. Assumes the second of the arrays doesn't have duplicate fileUUID's.
    private static func fileUUIDIntersection<S, T>(_ first: [S], _ second: [T]) -> [(S, T)] where T: FileUUID, S: FileUUID {
        var result = [(S, T)]()

        for secondElem in second {
            let filtered = first.filter({$0.fileUUID == secondElem.fileUUID})
            if filtered.count >= 1 {
                result += [(filtered[0], secondElem)]
            }
        }
        
        return result
    }
}
