//
//  Directory.swift
//  SyncServer
//
//  Created by Christopher Prince on 2/23/17.
//
//

import Foundation
import SMCoreLib
import SyncServer_Shared

// Meta info for files known to the client.

class Directory {
    static var session = Directory()
    
    private init() {
    }
    
    // Does not do `CoreData.sessionNamed(Constants.coreDataName).performAndWait`
    // Compares the passed fileIndex to the current DirecotoryEntry objects, and returns just the FileInfo objects we need to download/delete, if any. The directory is not changed as a result of this call, except for the case where the file isn't in the directory already, but has been deleted on the server.
    // 1/25/18; Now dealing with the case where a file is marked as deleted locally, but was undeleted on the server-- we need to download the file again.
    func checkFileIndex(serverFileIndex:[FileInfo]) throws ->
        (downloadFiles:[FileInfo]?, downloadDeletions:[FileInfo]?)  {
    
        var downloadFiles = [FileInfo]()
        var downloadDeletions = [FileInfo]()

        enum Action {
        case needToDownload
        case needToDownloadAndUndelete
        case needToDelete
        case none
        }
        
        for serverFile in serverFileIndex {
            var action:Action = .none

            if let entry = DirectoryEntry.fetchObjectWithUUID(uuid: serverFile.fileUUID) {
                // Have the file in client directory.

                if entry.deletedOnServer {
                    /* If we have the file marked as deleted:
                        a) File (still) deleted on the server: Don't need to do anything.
                        b) File not deleted on the server: We need to download.
                    */
                
                    if !serverFile.deleted {
                        // We think it's deleted; server thinks it's not deleted. The file must have been undeleted.
                        action = .needToDownloadAndUndelete
                    }
                }
                else {
                    if serverFile.deleted! {
                        action = .needToDelete
                    }
                    else if entry.fileVersion != serverFile.fileVersion {
                        // Not same version here locally as on server:
                        action = .needToDownload
                    }
                }
            }
            else {
                // File is unknown to the client
                
                if serverFile.deleted! {
                    // The file is unknown to the client, plus it's deleted on the server. No need to inform the client, but for consistency I'm going to create an entry in the directory.
                    let entry = DirectoryEntry.newObject() as! DirectoryEntry
                    entry.deletedOnServer = true
                    entry.fileUUID = serverFile.fileUUID
                    entry.fileVersion = serverFile.fileVersion
                    try CoreData.sessionNamed(Constants.coreDataName).context.save()
                }
                else {
                    action = .needToDownload
                }
            }
            
            // For these actions, we need to create or modify DirectoryEntry, but do this later. Not going to do these changes right now because then this state looks identical to having downloaded/deleted the file/version previously.
            
            switch action {
            case .needToDownload, .needToDownloadAndUndelete:
                downloadFiles += [serverFile]
                
            case .needToDelete:
                downloadDeletions += [serverFile]
                
            case .none:
                break
            }
        }

        return (downloadFiles.count == 0 ? nil : downloadFiles,
            downloadDeletions.count == 0 ? nil : downloadDeletions)
    }
    
    // Does not do `CoreData.sessionNamed(Constants.coreDataName).performAndWait`
    func updateAfterDownloadingFiles(downloads:[DownloadFileTracker]) {
        _ = downloads.map { dft in
            if let entry = DirectoryEntry.fetchObjectWithUUID(uuid: dft.fileUUID) {
                // This will really only ever happen in testing: A situation where the DirectoryEntry has been created for the file uuid, but we don't have a fileVersion assigned. e.g., The file gets uploaded (not using the sync system), then uploaded by the sync system, and then we get the download that was created not using the sync system.
#if !DEBUG
                assert(entry.fileVersion! < dft.fileVersion)
#endif
                entry.fileVersion = dft.fileVersion
                
                // 1/25/18; Deal with undeletion.
                if entry.deletedOnServer {
                    entry.deletedOnServer = false
                }
            }
            else {
                let newEntry = DirectoryEntry.newObject() as! DirectoryEntry
                newEntry.fileUUID = dft.fileUUID
                newEntry.fileVersion = dft.fileVersion
            }
        }
    }
    
    // Does not do `CoreData.sessionNamed(Constants.coreDataName).performAndWait`
    func updateAfterDownloadDeletingFiles(deletions:[SyncAttributes]) {
        deletions.forEach { attr in
            // Have already dealt with case where we didn't know about this file locally and were download deleting it.
            guard let entry = DirectoryEntry.fetchObjectWithUUID(uuid: attr.fileUUID) else {
                assert(false)
                return
            }
            
            entry.deletedOnServer = true
        }
    }
}
