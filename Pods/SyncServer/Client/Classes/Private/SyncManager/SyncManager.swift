//
//  SyncManager.swift
//  SyncServer
//
//  Created by Christopher Prince on 2/26/17.
//
//

import Foundation
import SMCoreLib
import SyncServer_Shared

class SyncManager {
    static let session = SyncManager()
    weak var delegate:SyncServerDelegate!
    private var _stopSync = false
    
    // The getter returns the current value and sets it to false. Operates in an atomic manner.
    var stopSync: Bool {
        set {
            Synchronized.block(self) {
                _stopSync = newValue
            }
        }
        
        get {
            var result: Bool = false
            
            Synchronized.block(self) {
                result = _stopSync
                _stopSync = false
            }
            
            return result
        }
    }

    private var callback:((SyncServerError?)->())?
    var desiredEvents:EventDesired = .defaults

    private init() {
    }
    
    enum StartError : Error {
    case error(String)
    }
    
    private func needToStop() -> Bool {
        if stopSync {
            EventDesired.reportEvent(.syncStopping, mask: self.desiredEvents, delegate: self.delegate)
            callback?(nil)
            return true
        }
        else {
            return false
        }
    }
    
    // TODO: *1* If we get an app restart when we call this method, and an upload was previously in progress, and we now have download(s) available, we need to reset those uploads prior to doing the downloads.
    func start(first: Bool = false, _ callback:((SyncServerError?)->())? = nil) {
        self.callback = callback
        
        // TODO: *1* This is probably the level at which we should ensure that multiple download operations are not taking place concurrently. E.g., some locking mechanism?
        
        if self.needToStop() {
            return
        }
        
        // First: Do we have previously queued downloads that need to be done?
        let nextResult = Download.session.next(first: first) {[weak self] nextCompletionResult in
            switch nextCompletionResult {
            case .fileDownloaded(let dft):
                var dcg: DownloadContentGroup!
                CoreDataSync.perform(sessionName: Constants.coreDataName) {
                    dcg = dft.group!
                }
                self?.downloadCompleted(dcg: dcg, callback:callback)
                
            case .appMetaDataDownloaded(dft: let dft):
                var dcg: DownloadContentGroup!
                CoreDataSync.perform(sessionName: Constants.coreDataName) {
                    dcg = dft.group!
                }
                self?.downloadCompleted(dcg: dcg, callback:callback)

            case .masterVersionUpdate:
                // Need to start all over again.
                self?.start(callback)
                
            case .error(let error):
                callback?(error)
            }
        }
        
        switch nextResult {
        case .currentGroupCompleted(let dcg):
            downloadCompleted(dcg: dcg, callback:callback)
            
        case .noDownloadsOrDeletions:
            checkForDownloads()

        case .error(let error):
            callback?(SyncServerError.otherError(error))
            
        case .started:
            // Don't do anything. `next` completion will invoke callback.
            return
            
        case .allDownloadsCompleted:
            checkForPendingUploads(first: true)
        }
    }
    
    private func downloadCompleted(dcg: DownloadContentGroup, callback:((SyncServerError?)->())? = nil) {
        var allCompleted:Bool!
        CoreDataSync.perform(sessionName: Constants.coreDataName) {
            allCompleted = dcg.allDftsCompleted()
            if allCompleted {
                dcg.status = .downloaded
                CoreData.sessionNamed(Constants.coreDataName).saveContext()
            }
        }
        
        if allCompleted {
            // All downloads completed for this group. Wrap it up.
            completeGroup(dcg: dcg)
        }
        else {
            // Downloads are not completed for this group. Recursively check for any next downloads (i.e., other groups). Using `async` so we don't consume extra space on the stack.
            DispatchQueue.global().async {
                self.start(callback)
            }
        }
    }
    
    private func completeGroup(dcg:DownloadContentGroup) {
        var contentDownloads:[DownloadFileTracker]!
        var downloadDeletions:[DownloadFileTracker]!
        
        Log.msg("Completed DownloadContentGroup: Checking for conflicts")
        
        // Deal with any content download conflicts and any download deletion conflicts.
        CoreDataSync.perform(sessionName: Constants.coreDataName) {
            contentDownloads = dcg.dfts.filter {$0.operation.isContents}
            downloadDeletions = dcg.dfts.filter {$0.operation.isDeletion}
        }
        
        ConflictManager.handleAnyContentDownloadConflicts(dfts: contentDownloads, delegate: self.delegate) {
            
            ConflictManager.handleAnyDownloadDeletionConflicts(dfts: downloadDeletions, delegate: self.delegate) {

                var groupContent:[DownloadOperation]!
                
                CoreDataSync.perform(sessionName: Constants.coreDataName) {
                    groupContent = dcg.dfts.map { dft in
                        var contentType:DownloadOperation.OperationType!
                        switch dft.operation! {
                        case .file:
                            contentType = .file(dft.localURL!)
                        case .appMetaData:
                            contentType = .appMetaData
                        case .deletion:
                            contentType = .deletion
                        }
                        
                        return DownloadOperation(type: contentType, attr: dft.attr)
                    }
                }
                
                if groupContent.count > 0 {
                    Thread.runSync(onMainThread: {
                        self.delegate!.syncServerFileGroupDownloadComplete(group: groupContent)
                    })
                }
                
                CoreDataSync.perform(sessionName: Constants.coreDataName) {                    
                    // Remove the DownloadContentGroup and related dft's -- We're finished their downloading.
                    dcg.dfts.forEach { dft in
                        dft.remove()
                    }
                    dcg.remove()
                    CoreData.sessionNamed(Constants.coreDataName).saveContext()
                }
            }

            // Downloads are completed for this group, but we may have other groups to download.
            DispatchQueue.global().async {
                self.start(self.callback)
            }
        }
    }

    // No DownloadFileTracker's queued up. Check the FileIndex to see if there are pending downloads on the server.
    private func checkForDownloads() {
        if self.needToStop() {
            return
        }
        
        Download.session.check() { checkCompletion in
            switch checkCompletion {
            case .noDownloadsOrDeletionsAvailable:
                self.checkForPendingUploads(first: true)
            
            case .downloadsAvailable(numberOfContentDownloads:let numberContentDownloads, numberOfDownloadDeletions:let numberDownloadDeletions):
                // This is not redundant with the `willStartDownloads` reporting in `Download.session.next` because we're calling start with first=false (implicitly), so willStartDownloads will not get reported twice.
                EventDesired.reportEvent(
                    .willStartDownloads(numberContentDownloads: UInt(numberContentDownloads), numberDownloadDeletions: UInt(numberDownloadDeletions)),
                    mask: self.desiredEvents, delegate: self.delegate)
                
                // We've got DownloadFileTracker's queued up now. Go deal with them!
                self.start(self.callback)
                
            case .error(let error):
                self.callback?(error)
            }
        }
    }
    
    private func checkForPendingUploads(first: Bool = false) {
        if self.needToStop() {
            return
        }
        
        let nextResult = Upload.session.next(first: first) {[weak self] nextCompletion in
            switch nextCompletion {
            case .fileUploaded(let attr, let uft):
                self?.contentWasUploaded(attr: attr, uft: uft)

            case .appMetaDataUploaded(uft: let uft):
                self?.contentWasUploaded(attr: nil, uft: uft)
                
            case .uploadDeletion(let fileUUID):
                if let selfObj = self {
                    EventDesired.reportEvent(.singleUploadDeletionComplete(fileUUID: fileUUID), mask: selfObj.desiredEvents, delegate: selfObj.delegate)
                    // Recursively see if there is a next upload to do.
                    selfObj.checkForPendingUploads()
                }
                
            case .masterVersionUpdate:
                // Things have changed on the server. Check for downloads again. Don't go all the way back to `start` because we know that we don't have queued downloads.
                self?.checkForDownloads()
                
            case .error(let error):
                self?.callback?(error)
            }
        }
        
        switch nextResult {
        case .started:
            // Don't do anything. `next` completion will invoke callback.
            break
            
        case .noUploads:
            SyncManager.cleanupUploads()
            callback?(nil)
            
        case .allUploadsCompleted:
            self.doneUploads()
            
        case .error(let error):
            callback?(error)
        }
    }
    
    private func contentWasUploaded(attr:SyncAttributes?, uft: UploadFileTracker) {
        var operation: FileTracker.Operation!
        var fileUUID:String!
        
        CoreDataSync.perform(sessionName: Constants.coreDataName) {
            operation = uft.operation
            fileUUID = uft.fileUUID
        }
        
        switch operation! {
        case .file:
            EventDesired.reportEvent(.singleFileUploadComplete(attr: attr!), mask: self.desiredEvents, delegate: self.delegate)
            
        case .appMetaData:
            EventDesired.reportEvent(.singleAppMetaDataUploadComplete(fileUUID: fileUUID), mask: self.desiredEvents, delegate: self.delegate)
        case .deletion:
            assert(false)
        }
        
        // Recursively see if there is a next upload to do.
        DispatchQueue.global().async {
            self.checkForPendingUploads()
        }
    }
    
    private func doneUploads() {
        Upload.session.doneUploads { completionResult in
            switch completionResult {
            case .masterVersionUpdate:
                self.checkForDownloads()
                
            case .error(let error):
                self.callback?(error)
                
            // `numTransferred` may not be accurate in the case of retries/recovery.
            case .doneUploads(numberTransferred: _):
                var uploadQueue:UploadQueue!
                var contentUploads:[UploadFileTracker]!
                var uploadDeletions:[UploadFileTracker]!
                var errorResult:SyncServerError?

                CoreDataSync.perform(sessionName: Constants.coreDataName) {
                    // 4/18/18; Got a crash here during testing because `Upload.getHeadSyncQueue()` returned nil. How is that possible? An earlier test failed-- wonder if it could have "leaked" into a later test?
                    uploadQueue = Upload.getHeadSyncQueue()
                    if uploadQueue == nil {
                        errorResult = .generic("Nil result from getHeadSyncQueue.")
                        return
                    }
                    
                    contentUploads = uploadQueue.uploadFileTrackers.filter {$0.operation.isContents}
                }
                
                if errorResult != nil {
                    self.callback?(errorResult)
                    return
                }
                
                if contentUploads.count > 0 {
                    EventDesired.reportEvent(.contentUploadsCompleted(numberOfFiles: contentUploads.count), mask: self.desiredEvents, delegate: self.delegate)
                }
    
                CoreDataSync.perform(sessionName: Constants.coreDataName) { [unowned self] in
                    if contentUploads.count > 0 {
                        // Each of the DirectoryEntry's for the uploads needs to now be given its version, as uploaded. And appMetaData needs to be updated in directory if it has been updated on this upload.
                        contentUploads.forEach { uft in
                            guard let uploadedEntry = DirectoryEntry.fetchObjectWithUUID(uuid: uft.fileUUID) else {
                                assert(false)
                                return
                            }

                            // 1/27/18; [1]. It's safe to update the local directory entry version(s) -- we've done the upload *and* we've done the DoneUploads too.
                            
                            // Only if we're updating a file do we need to update our local directory file version. appMetaData uploads don't deal with file versions.
                            if uft.operation! == .file {
                                uploadedEntry.fileVersion = uft.fileVersion
                            }
                            
                            // We may need to update the appMetaData and version for either a file upload (which can also update the appMetaData) or (definitely) for an appMetaData upload.
                             if let _ = uft.appMetaData {
                                uploadedEntry.appMetaData = uft.appMetaData
                                uploadedEntry.appMetaDataVersion = uft.appMetaDataVersion
                            }
                            
                            // Deal with special case where we had marked directory entry as `deletedOnServer`.
                            if uft.uploadUndeletion && uploadedEntry.deletedOnServer {
                                uploadedEntry.deletedOnServer = false
                            }
                            
                            do {
                                try uft.remove()
                            } catch {
                                self.delegate?.syncServerErrorOccurred(error:
                                    .couldNotRemoveFileTracker)
                            }
                        }
                    }
                    
                    uploadDeletions = uploadQueue.uploadFileTrackers.filter {$0.operation.isDeletion}
                } // end perform

                if uploadDeletions.count > 0 {
                    EventDesired.reportEvent(.uploadDeletionsCompleted(numberOfFiles: uploadDeletions.count), mask: self.desiredEvents, delegate: self.delegate)
                }
                
                CoreDataSync.perform(sessionName: Constants.coreDataName) {
                    if uploadDeletions.count > 0 {
                        // Each of the DirectoryEntry's for the uploads needs to now be marked as deleted.
                        uploadDeletions.forEach { uft in
                            guard let uploadedEntry = DirectoryEntry.fetchObjectWithUUID(uuid: uft.fileUUID) else {
                                assert(false)
                                return
                            }

                            uploadedEntry.deletedLocally = true
                            do {
                                try uft.remove()
                            } catch {
                                errorResult = .couldNotRemoveFileTracker
                            }
                        }
                    }
                    
                    CoreData.sessionNamed(Constants.coreDataName).remove(uploadQueue)
                    
                    do {
                        try CoreData.sessionNamed(Constants.coreDataName).context.save()
                    } catch (let error) {
                        errorResult = .coreDataError(error)
                        return
                    }
                } // end perform
                
                SyncManager.cleanupUploads()
                
                self.callback?(errorResult)
            }
        }
    }

    // 4/22/18; I ran into the need for this during a crash Dany was having. For some reason there were 10 uft's on his app that were marked as uploaded. But for some reason had never been deleted. I'm calling this from places where there should not be uft's in this state-- so they should be removed. This is along the lines of garbage collection. Not sure why it's needed...
    // Not marking this as `private` so I can add a test case.
    static func cleanupUploads() {
        CoreDataSync.perform(sessionName: Constants.coreDataName) {
            let uploadedUfts = UploadFileTracker.fetchAll().filter { $0.status == .uploaded }
            uploadedUfts.forEach { uft in
                do {
                    try uft.remove()
                } catch (let error) {
                    Log.error("Error removing uft: \(error)")
                }
            }
            
            CoreData.sessionNamed(Constants.coreDataName).saveContext()
        }
    }
}

