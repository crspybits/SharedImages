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
    func checkFileIndex(fileIndex:[FileInfo]) throws ->
        (downloadFiles:[FileInfo]?, downloadDeletions:[FileInfo]?)  {
    
        var downloadFiles = [FileInfo]()
        var downloadDeletions = [FileInfo]()

        enum Action {
        case needToDownload
        case needToDelete
        case none
        }
        
        for file in fileIndex {
            var action:Action = .none

            if let entry = DirectoryEntry.fetchObjectWithUUID(uuid: file.fileUUID) {
                // Have the file in client directory.
                
                // If we already know the file is deleted on the server, then don't need to worry about it.
                if !entry.deletedOnServer {
                    
                    if file.deleted! {
                        action = .needToDelete
                    }
                    else if entry.fileVersion != file.fileVersion {
                        // Not same version here locally as on server:
                        action = .needToDownload
                    }
                }
            }
            else {
                // File is unknown to the client
                
                if file.deleted! {
                    // The file is unknown to the client, plus it's deleted on the server. No need to inform the client, but for consistency I'm going to create an entry in the directory.
                    let entry = DirectoryEntry.newObject() as! DirectoryEntry
                    entry.deletedOnServer = true
                    entry.fileUUID = file.fileUUID
                    entry.fileVersion = file.fileVersion
                    try CoreData.sessionNamed(Constants.coreDataName).context.save()
                }
                else {
                    action = .needToDownload
                }
            }
            
            // For these actions, we need to create or modify DirectoryEntry, but do this later. Not going to do these changes right now because then this state looks identical to having downloaded/deleted the file/version previously.
            
            switch action {
            case .needToDownload:
                downloadFiles += [file]
                
            case .needToDelete:
                downloadDeletions += [file]
                
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
                assert(entry.fileVersion! < dft.fileVersion)
                entry.fileVersion = dft.fileVersion
            }
            else {
                let newEntry = DirectoryEntry.newObject() as! DirectoryEntry
                newEntry.fileUUID = dft.fileUUID
                newEntry.fileVersion = dft.fileVersion
            }
        }
    }
    
    // Does not do `CoreData.sessionNamed(Constants.coreDataName).performAndWait`
    func updateAfterDownloadDeletingFiles(deletions:[DownloadFileTracker]) {
        _ = deletions.map { dft in
            // Have already dealt with case where we didn't know about this file locally and were download deleting it.
            guard let entry = DirectoryEntry.fetchObjectWithUUID(uuid: dft.fileUUID) else {
                assert(false)
                return
            }
            
            entry.deletedOnServer = true
        }
    }
}
