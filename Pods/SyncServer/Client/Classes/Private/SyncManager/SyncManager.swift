//
//  SyncManager.swift
//  SyncServer
//
//  Created by Christopher Prince on 2/26/17.
//
//

import Foundation
import SMCoreLib

class SyncManager {
    static let session = SyncManager()
    weak var delegate:SyncServerDelegate?
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

#if DEBUG
    weak var testingDelegate:SyncServerTestingDelegate?
#endif

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
        
        // First: Do we have previously queued downloads that need to be downloaded?
        let nextResult = Download.session.next(first: first) { nextCompletionResult in
            switch nextCompletionResult {
            case .fileDownloaded(let url, let attr, let dft):
                func after() {
                    CoreData.sessionNamed(Constants.coreDataName).performAndWait() {
                        Directory.session.updateAfterDownloadingFiles(downloads: [dft])
                    
                        // 9/16/17; We're doing downloads in an eventually consistent manner. Remove the DownloadFileTracker-- we don't want to repeat this download. See http://www.spasticmuffin.biz/blog/2017/09/15/making-downloads-more-flexible-in-the-syncserver/
                        CoreData.sessionNamed(Constants.coreDataName).remove(dft)
                        CoreData.sessionNamed(Constants.coreDataName).saveContext()
                    }
                    
                    // Recursively check for any next download. Using `async` so we don't consume extra space on the stack.
                    DispatchQueue.global().async {
                        self.start(callback)
                    }
                }

                func normalDelegateAndAfterCalls() {
                    Thread.runSync(onMainThread: {
                        ConflictManager.handleAnyFileDownloadConflict(attr: attr, url: url, delegate: self.delegate!) { ignoreDownload in
                        
                            if ignoreDownload == nil {
                                // Not 100% sure we're running on main thread-- its possible that the client didn't call the completion on the main thread.
                                Thread.runSync(onMainThread: {
                                    self.delegate!.syncServerSingleFileDownloadComplete(url: url, attr: attr)
                                })
                            }
                            else {
                                Log.msg("ignoreDownload not nil")
                            }
                            
                            DispatchQueue.global(qos: .default).sync {
                                after()
                            }
                        }
                    })
                }
                
                if self.delegate == nil {
                    after()
                }
                else {
#if DEBUG
                    // Assuming that in testing self.delegate will not be nil.
                    if self.testingDelegate == nil {
                        normalDelegateAndAfterCalls()
                    }
                    else {
                        Thread.runSync(onMainThread: {
                            self.testingDelegate!.singleFileDownloadComplete(url: url, attr: attr) {
                                after()
                            }
                        })
                    }
#else
                    normalDelegateAndAfterCalls()
#endif
                }

            case .masterVersionUpdate:
                // Need to start all over again.
                self.start(callback)
                
            case .error(let error):
                callback?(error)
            }
        }
        
        switch nextResult {
        case .noDownloadsOrDeletions:
            checkForDownloads()

        case .error(let error):
            callback?(error)
            
        case .started:
            // Don't do anything. `next` completion will invoke callback.
            return
            
        case .allDownloadsCompleted:
            allDownloadsCompleted()
        }
    }
    
    private func allDownloadsCompleted() {
        // Inform client via delegate of any download deletions.

        var deletions = [SyncAttributes]()
        var downloadDeletionDfts:[DownloadFileTracker]!

        CoreData.sessionNamed(Constants.coreDataName).performAndWait() {
            let dfts = DownloadFileTracker.fetchAll()
            downloadDeletionDfts = dfts.filter {$0.deletedOnServer == true}

            downloadDeletionDfts.forEach { dft in
                let attr = SyncAttributes(fileUUID: dft.fileUUID, mimeType: dft.mimeType!, creationDate: dft.creationDate! as Date, updateDate: dft.updateDate! as Date)
                deletions += [attr]
            }
            
            Log.msg("Deletions: count: \(deletions.count)")
        }
    
        if deletions.count > 0 {
            if let delegate = self.delegate {
                /* Callback parameters:
                    `ignoreDownloadDeletions`: The download deletions that conflict resolution tells us *not* to delete.
                    `alreadyDeletedLocally`: Don't call the delegate method `syncServerShouldDoDeletions` for these download deletions. These have already been deleted locally.
                */
                ConflictManager.handleAnyDownloadDeletionConflicts(
                    downloadDeletionAttrs: deletions, delegate: delegate) { ignoreDownloadDeletions, havePendingUploadDeletions in
                    
                    let makeDelegateCalls = deletions.filter({ deletion in
                        let ignore = (havePendingUploadDeletions + ignoreDownloadDeletions).filter({$0.fileUUID == deletion.fileUUID})
                        return ignore.count == 0
                    })
                    
                    if makeDelegateCalls.count > 0 {
                        Thread.runSync(onMainThread: {
                            delegate.syncServerShouldDoDeletions(downloadDeletions: makeDelegateCalls)
                        })
                    }
                    
                    let deleteFromLocalDirectory = deletions.filter({ deletion in
                        let ignore = ignoreDownloadDeletions.filter({$0.fileUUID == deletion.fileUUID})
                        return ignore.count == 0
                    })
                    
                    // I'd like to wrap up by switching to the original thread we were on prior to switching to the main thread. Not quite sure how to do that. Do this instead.
                    DispatchQueue.global(qos: .default).sync {[unowned self] in
                        self.wrapup(deletions: deletions, deleteTheseLocally: deleteFromLocalDirectory)
                    }
                }
            }
        }
        else {
            wrapup(deletions: [], deleteTheseLocally: [])
        }
    }
    
    private func wrapup(deletions: [SyncAttributes], deleteTheseLocally: [SyncAttributes]) {
        var errorResult:Error?
    
        // This is broken out of the above `performAndWait` to not get a deadlock when I do the `Thread.runSync(onMainThread:`.
        if deletions.count > 0 {
            CoreData.sessionNamed(Constants.coreDataName).performAndWait() {
                Directory.session.updateAfterDownloadDeletingFiles(deletions: deleteTheseLocally)
                
                // This will be removing DownloadFileTracker's for download deletions only. The DownloadFileTrackers for file downloads will have been removed already.
                DownloadFileTracker.removeAll()
                do {
                    try CoreData.sessionNamed(Constants.coreDataName).context.save()
                } catch (let error) {
                    errorResult = error
                    return
                }
            }
        }
    
        guard errorResult == nil else {
            callback?(.coreDataError(errorResult!))
            return
        }
    
        self.checkForPendingUploads(first: true)
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
                
            case .downloadsAvailable(numberOfDownloadFiles: let numberFileDownloads, numberOfDownloadDeletions: let numberDownloadDeletions):
            
                // This is not redundant with the `willStartDownloads` reporting in `Download.session.next` because we're calling start with first=false (implicitly), so willStartDownloads will not get reported twice.
                EventDesired.reportEvent(
                    .willStartDownloads(numberFileDownloads: UInt(numberFileDownloads), numberDownloadDeletions: UInt(numberDownloadDeletions)),
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
        
        let nextResult = Upload.session.next(first: first) { nextCompletion in
            switch nextCompletion {
            case .fileUploaded(let attr):
                EventDesired.reportEvent(.singleFileUploadComplete(attr: attr), mask: self.desiredEvents, delegate: self.delegate)
                
                func after() {
                    // Recursively see if there is a next upload to do.
                    DispatchQueue.global().async {
                        self.checkForPendingUploads()
                    }
                }
                
#if DEBUG
                if self.testingDelegate == nil {
                    after()
                }
                else {
                    Thread.runSync(onMainThread: {
                        self.testingDelegate!.syncServerSingleFileUploadCompleted(next: {
                            after()
                        })
                    })
                }
#else
                after()
#endif

            case .uploadDeletion(let fileUUID):
                EventDesired.reportEvent(.singleUploadDeletionComplete(fileUUID: fileUUID), mask: self.desiredEvents, delegate: self.delegate)
                // Recursively see if there is a next upload to do.
                self.checkForPendingUploads()
                
            case .masterVersionUpdate:
                // Things have changed on the server. Check for downloads again. Don't go all the way back to `start` because we know that we don't have queued downloads.
                self.checkForDownloads()
                
            case .error(let error):
                self.callback?(error)
            }
        }
        
        switch nextResult {
        case .started:
            // Don't do anything. `next` completion will invoke callback.
            break
            
        case .noUploads:
            callback?(nil)
            
        case .allUploadsCompleted:
            self.doneUploads()
            
        case .error(let error):
            callback?(error)
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
                var fileUploads:[UploadFileTracker]!
                var uploadDeletions:[UploadFileTracker]!
                
                CoreData.sessionNamed(Constants.coreDataName).performAndWait() {
                    uploadQueue = Upload.getHeadSyncQueue()!
                    fileUploads = uploadQueue.uploadFileTrackers.filter {!$0.deleteOnServer}
                }
                
                if fileUploads.count > 0 {
                    EventDesired.reportEvent(.fileUploadsCompleted(numberOfFiles: fileUploads.count), mask: self.desiredEvents, delegate: self.delegate)
                }
                
                CoreData.sessionNamed(Constants.coreDataName).performAndWait() {
                    if fileUploads.count > 0 {
                        // Each of the DirectoryEntry's for the uploads needs to now be given its version, as uploaded.
                        fileUploads.forEach { uft in
                            guard let uploadedEntry = DirectoryEntry.fetchObjectWithUUID(uuid: uft.fileUUID) else {
                                assert(false)
                                return
                            }
                            
                            // 1/27/18; [1]. It's safe to update the local directory entry with the new file version-- we've done the file upload *and* we've done the DoneUploads too.
                            uploadedEntry.fileVersion = uft.fileVersion
                            CoreData.sessionNamed(Constants.coreDataName).remove(uft)
                        }
                    }
                    
                    uploadDeletions = uploadQueue.uploadFileTrackers.filter {$0.deleteOnServer}
                }

                if uploadDeletions.count > 0 {
                    EventDesired.reportEvent(.uploadDeletionsCompleted(numberOfFiles: uploadDeletions.count), mask: self.desiredEvents, delegate: self.delegate)
                }
                
                var errorResult:SyncServerError?
                CoreData.sessionNamed(Constants.coreDataName).performAndWait() {
                    if uploadDeletions.count > 0 {
                        // Each of the DirectoryEntry's for the uploads needs to now be marked as deleted.
                        uploadDeletions.forEach { uft in
                            guard let uploadedEntry = DirectoryEntry.fetchObjectWithUUID(uuid: uft.fileUUID) else {
                                assert(false)
                                return
                            }

                            uploadedEntry.deletedOnServer = true
                            CoreData.sessionNamed(Constants.coreDataName).remove(uft)
                        }
                    }
                    
                    CoreData.sessionNamed(Constants.coreDataName).remove(uploadQueue)
                    
                    do {
                        try CoreData.sessionNamed(Constants.coreDataName).context.save()
                    } catch (let error) {
                        errorResult = .coreDataError(error)
                        return
                    }
                }
                
                self.callback?(errorResult)
            }
        }
    }
}

