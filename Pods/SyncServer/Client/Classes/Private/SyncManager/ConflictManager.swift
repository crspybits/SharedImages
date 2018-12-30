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
    private static func handleAnyContentDownloadConflicts(dfts:[DownloadFileTracker], ignoreDownloads: [DownloadFileTracker], delegate: SyncServerDelegate,
        completion:@escaping (_ ignoreDownloads:[DownloadFileTracker])->()) {
    
        // Are there more dft's to check for conflicts?
        if dfts.count == 0 {
            completion(ignoreDownloads)
        }
        else {
            let dft = dfts[0]
            var possiblyConflictingContent: ServerContentType = .appMetaData
            var attr: SyncAttributes!
            
            CoreDataSync.perform(sessionName: Constants.coreDataName) {
                if let url = dft.localURL {
                    if dft.appMetaData == nil {
                        possiblyConflictingContent = .file(url)
                    }
                    else {
                        possiblyConflictingContent = .both(downloadURL: url)
                    }
                }
                
                attr = dft.attr
            }
            
            Thread.runSync(onMainThread: {
                ConflictManager.handleAnyContentDownloadConflict(attr: attr, content: possiblyConflictingContent, delegate: delegate) { ignoreDownload in
                    
                    var updatedIgnoreDownloads = ignoreDownloads
                    
                    if let _ = ignoreDownload {
                        updatedIgnoreDownloads += [dft]
                    }
                    
                    DispatchQueue.global().async {
                        handleAnyContentDownloadConflicts(dfts:dfts.tail(), ignoreDownloads: updatedIgnoreDownloads, delegate: delegate, completion:completion)
                    }
                }
            })
        }
    }
    
    static func handleAnyContentDownloadConflicts(dfts:[DownloadFileTracker], delegate: SyncServerDelegate, completion:@escaping (_ ignoreDownloads:[DownloadFileTracker])->()) {
    
        handleAnyContentDownloadConflicts(dfts: dfts, ignoreDownloads: [], delegate: delegate, completion: completion)
    }
    
    // completion's are called when the client has resolved all conflicts if there are any. If there are no conflicts, the call to the completion is synchronous.
    static func handleAnyContentDownloadConflict(attr:SyncAttributes, content: ServerContentType, delegate: SyncServerDelegate, completion:@escaping (_ keepThisOne: SyncAttributes?)->()) {
    
        var resolver: SyncServerConflict<ContentDownloadResolution>?
        
        var conflictingUploadDeletions: [UploadFileTracker]!
        var conflictingContentUploads: [UploadFileTracker]!
        
        CoreDataSync.perform(sessionName: Constants.coreDataName) {
            let pendingUploads = UploadFileTracker.fetchAll()
            
            // For this content download we could have (a) an upload deletion conflict, (b) content upload conflict(s), or (c) both an upload deletion conflict and content upload conflict(s).
            
            // Do we have a pending upload deletion that conflicts with the file download? In this case there could be at most a single upload deletion. It's an error for the client to try to queue up more than one deletion (with sync's between them).
            conflictingUploadDeletions = pendingUploads.filter {
                // 4/22/18; The optional chaining here is to deal with a problem with data migrations. It should only be temporarily necessary.
                return ($0.operation?.isDeletion ?? false) && $0.fileUUID == attr.fileUUID
            }

            // Do we have pending content upload(s) that conflict with the content download? In this case there could be more than one upload with the same uuid. For example, if the client does a file upload of uuid X, syncs, then another upload of X, and then sync.
            conflictingContentUploads = pendingUploads.filter {
                // 4/22/18; As above.
                ($0.operation?.isContents ?? false) && $0.fileUUID == attr.fileUUID
            }
        }
        
        var conflictType:ConflictingClientOperation?
        
        if conflictingUploadDeletions.count > 0 && conflictingContentUploads.count > 0 {
            // This can arise when a file was queued for upload, synced, and then queued for deletion and synced
            conflictType = .both
        }
        else if conflictingContentUploads.count > 0 {
            CoreDataSync.perform(sessionName: Constants.coreDataName) {
                let conflictingContent =                 conflictContentTypeFor(conflictingContentUploads: conflictingContentUploads)
                conflictType = .contentUpload(conflictingContent)
            }
        }
        else if conflictingUploadDeletions.count > 0 {
            conflictType = .uploadDeletion
        }
        
        if let conflictType = conflictType {
            resolver = SyncServerConflict<ContentDownloadResolution>(
                conflictType: conflictType, resolutionCallback: { resolution in
            
                switch resolution {
                case .acceptContentDownload:
                    removeManagedObjects(conflictingContentUploads, delegate: delegate)
                    removeManagedObjects(conflictingUploadDeletions, delegate: delegate)
                    completion(nil)
                    
                case .rejectContentDownload(let uploadResolution):
                    if uploadResolution.removeContentUploads {
                        removeManagedObjects(conflictingContentUploads, delegate: delegate)
                    }
                    
                    if uploadResolution.removeUploadDeletions {
                        removeManagedObjects(conflictingUploadDeletions, delegate: delegate)
                    }
                    completion(attr)
                }
            })
        }
        
        if let resolver = resolver {
            // See note [1] below re: why I'm not calling this on the main thread.
            delegate.syncServerMustResolveContentDownloadConflict(content, downloadedContentAttributes: attr, uploadConflict: resolver)
        }
        else {
            completion(nil)
        }
    }
    
    static func conflictContentTypeFor(conflictingContentUploads: [UploadFileTracker]) -> ConflictingClientOperation.ContentType {
    
        let appMetaDataUploads = conflictingContentUploads.filter { uft in
            uft.operation == .appMetaData
        }
        
        let fileUploads = conflictingContentUploads.filter { uft in
            // We could have a file upload here that *also* is uploading a new appMetaData version.
            uft.operation == .file
        }

        // We could have a file upload that *also* is uploading a new appMetaData version.
        let fileWithAppMetaDataUpload = conflictingContentUploads.filter { uft in
            // Check the appMetaData itself because the appMetaDataVersion doen't get set until close to actual upload.
            uft.operation == .file && uft.appMetaData != nil
        }

        if fileWithAppMetaDataUpload.count > 0 {
            // Count this as "both" even though it's within the same file.
            return .both
        }
        else if appMetaDataUploads.count > 0 && fileUploads.count > 0  {
            return .both
        }
        else if appMetaDataUploads.count > 0 {
            return .appMetaData
        }
        else {
            return .file
        }
    }
    
    static func handleAnyDownloadDeletionConflicts(dfts:[DownloadFileTracker], delegate: SyncServerDelegate, completion:@escaping (_ deleteAllOfThese: Set<SyncAttributes>, _ updateDirectoryAfterDownloadDeletingFiles:(()->())?)->()) {
        
        if dfts.count == 0 {
            completion(Set<SyncAttributes>(), nil)
            return
        }
        
        var deletionAttrs:[SyncAttributes]!

        CoreDataSync.perform(sessionName: Constants.coreDataName) {
            deletionAttrs = dfts.map {$0.attr}
            Log.msg("Deletions: count: \(dfts.count)")
        }

        ConflictManager.handleAnyDownloadDeletionConflicts(
            downloadDeletionAttrs: deletionAttrs, delegate: delegate) { ignoreDownloadDeletions, havePendingUploadDeletions, uploadUndeletions in
                
            let deleteFromLocalDirectory = deletionAttrs.filter({ deletion in
                let ignore = ignoreDownloadDeletions.filter({
                    var matchesGroup = false
                    if $0.fileGroupUUID != nil {
                        matchesGroup = $0.fileGroupUUID == deletion.fileGroupUUID
                    }
                    
                    return $0.fileUUID == deletion.fileUUID || matchesGroup
                })
                return ignore.count == 0
            })
            
            var ignoreDownloadDeletionsExpandedForGroups =  Set<SyncAttributes>(ignoreDownloadDeletions)
            ignoreDownloadDeletions.forEach { downloadDeletion in
                if let fileGroupUUID = downloadDeletion.fileGroupUUID {
                    let result = deletionAttrs.filter {$0.fileGroupUUID == fileGroupUUID}
                    ignoreDownloadDeletionsExpandedForGroups.formUnion(result)
                }
            }
            
            func updateAfterDownloadDeletingFiles() {
                Directory.session.updateAfterDownloadDeletingFiles(deletions: deleteFromLocalDirectory, pendingUploadUndeletions: uploadUndeletions)
            }
            
            var deleteAllOfThese: Set<SyncAttributes>!
            
            CoreDataSync.perform(sessionName: Constants.coreDataName) {
                deleteAllOfThese = ignoreDownloadDeletionsExpandedForGroups.union(
                    havePendingUploadDeletions)
            }
                
            // I'd like to wrap up by switching to the original thread we were on prior to switching to the main thread. Not quite sure how to do that. Do this instead.
            DispatchQueue.global().async {
                completion(deleteAllOfThese, updateAfterDownloadDeletingFiles)
            }
        }
    }
    
    // In the completion, `clientSaysKeepTheseOnes` gives attr's for the files the client doesn't wish to have deleted by the given download deletions.
    static func handleAnyDownloadDeletionConflicts(downloadDeletionAttrs:[SyncAttributes], delegate: SyncServerDelegate,
        completion:@escaping (_ clientSaysKeepTheseOnes: [SyncAttributes], _ havePendingUploadDeletions: [SyncAttributes], _ uploadUndeletions: [SyncAttributes])->()) {
    
        var remainingDownloadDeletionAttrs = downloadDeletionAttrs
        
        // If we have a pending upload deletion, no worries. Then we have a "conflict" between a download deletion, and an upload deletion. Someone just beat us to it. No need to keep on with our upload deletion.
        // Let's go ahead and remove the pending deletions, if any.
        
        var conflicts = [(downloadDeletion: SyncAttributes, uploadConflict: SyncServerConflict<DownloadDeletionResolution>)]()
        
        // We'll want no deletion delegate callback for these.
        var havePendingUploadDeletions = [SyncAttributes]()
        
        var conflictingContentUploads:[(UploadFileTracker, SyncAttributes)]!
        var pendingContentUploads:[UploadFileTracker]!
        
        CoreDataSync.perform(sessionName: Constants.coreDataName) {
            let pendingUploadDeletions = UploadFileTracker.fetchAll().filter({$0.operation.isDeletion})
            
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
            
            pendingContentUploads = UploadFileTracker.fetchAll().filter({$0.operation.isContents})
            conflictingContentUploads = fileUUIDIntersection(pendingContentUploads, remainingDownloadDeletionAttrs)
        }
        
        if conflictingContentUploads.count > 0 {
            var numberConflicts = conflictingContentUploads.count
            
            var deletionsToIgnore = [SyncAttributes]()
            var uploadUndeletions = [SyncAttributes]()
            
            conflictingContentUploads.forEach { (conflictUft, attr) in
                // Note that I'm depending in the download deletion case on there just being a single uft passed as a parameter to `conflictContentTypeFor`-- because I'm assuming below in the `both` case in .keepContentUpload is for a file upload.
                var conflictingContent:ConflictingClientOperation.ContentType!
                CoreDataSync.perform(sessionName: Constants.coreDataName) {
                    conflictingContent = conflictContentTypeFor(conflictingContentUploads: [conflictUft])
                }
                
                let resolver = SyncServerConflict<DownloadDeletionResolution>(
                    conflictType: .contentUpload(conflictingContent), resolutionCallback: { resolution in
                    
                    // The following code runs *after* the client has made their decision as to how to handle the conflict. i.e., `resolution` tells us how they want to handle the conflict.
                    var error = false
                    
                    switch resolution {
                    case .acceptDownloadDeletion:
                        removeConflictingUpload(pendingContentUploads: pendingContentUploads, fileUUID: attr.fileUUID, delegate: delegate)
                        
                    case .rejectDownloadDeletion(let uploadResolution):
                        switch uploadResolution {
                        case .keepContentUpload:
                            // Need to mark the uft as an upload undeletion, but only in the case of a file upload-- can't do this for an appMetaData upload because we don't have file contents in that case to replace the already deleted cloud storage file.
                            switch conflictingContent! {
                            case .both, .file:
                                markUftAsUploadUndeletion(pendingContentUploads: pendingContentUploads, fileUUID: attr.fileUUID)
                                uploadUndeletions += [attr]
                                
                            case .appMetaData:
                                error = true

                                Thread.runSync(onMainThread: {
                                    delegate.syncServerErrorOccurred(error: .appMetaDataUploadUndeletionAttempt)
                                })
        
                                // Just so this error doesn't cause an infinite loop attempting to do the download deletion-- I'm going to convert this to an .acceptDownloadDeletion
                                removeConflictingUpload(pendingContentUploads: pendingContentUploads, fileUUID: attr.fileUUID, delegate: delegate)
                            }

                        case .removeContentUpload:
                            removeConflictingUpload(pendingContentUploads: pendingContentUploads, fileUUID: attr.fileUUID, delegate: delegate)
                        } // End switch uploadResolution
                        
                        if !error {
                            // We're going to disregard the download deletion, and for files that are part of a group, need to disregard the download deletions for all files in the group.
                            deletionsToIgnore += [attr]
                        }
                    }
                    
                    numberConflicts -= 1
                    
                    if numberConflicts == 0 {
                        completion(deletionsToIgnore, havePendingUploadDeletions, uploadUndeletions)
                    }
                })
                
                conflicts += [(attr, resolver)]
            } // End conflictingContentUploads.forEach
        }
        
        if conflicts.count > 0 {
            // See note [1] below re: why I'm not calling this on the main thread.
            delegate.syncServerMustResolveDownloadDeletionConflicts(conflicts: conflicts)
        }
        else {
            completion([], havePendingUploadDeletions, [])
        }
    }
    
    // Where this gets tricky is what we need is that only the very first uft for this fileUUID needs to be an upload undeletion. i.e., the uft that will get serviced the first.
    private static func markUftAsUploadUndeletion(pendingContentUploads: [UploadFileTracker], fileUUID: String) {
    
        CoreDataSync.perform(sessionName: Constants.coreDataName) {
            var toKeep = pendingContentUploads.filter({$0.fileUUID == fileUUID})
            toKeep.sort(by: { (uft1, uft2) -> Bool in
                return uft1.age < uft2.age
            })
            toKeep[0].uploadUndeletion = true
            
            if let fileGroupUUID = toKeep[0].fileGroupUUID {
                // Mark all other entries in the group, if any, as deletedOnServer-- to allow them to be upload undeleted.
                let entries = DirectoryEntry.fetchAll()
                let pendingUndeletionEntries = entries.filter {$0.fileGroupUUID == fileGroupUUID && $0.fileUUID != fileUUID}
                pendingUndeletionEntries.forEach { pendingUndeletionEntry in
                    pendingUndeletionEntry.deletedOnServer = true
                }
            }
            
            CoreData.sessionNamed(Constants.coreDataName).saveContext()
        }
    }
    
    // Remove any pending content upload's with this UUID.
    private static func removeConflictingUpload(pendingContentUploads: [UploadFileTracker], fileUUID:String, delegate: SyncServerDelegate) {
        // [1] Having deadlock issue here. Resolving it by documenting that delegate is *not* called on main thread for the two conflict delegate methods. Not the best solution.
        CoreDataSync.perform(sessionName: Constants.coreDataName) {
            let toDelete = pendingContentUploads.filter({$0.fileUUID == fileUUID})
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
        CoreDataSync.perform(sessionName: Constants.coreDataName) {
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
