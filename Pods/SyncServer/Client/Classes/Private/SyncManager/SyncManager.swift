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
        
        // First: Do we have previously queued downloads that need to be done?
        let nextResult = Download.session.next(first: first) {[weak self] nextCompletionResult in
            switch nextCompletionResult {
            case .fileDownloaded(let url, let attr, let dft):
                self?.downloadCompleted(dft: dft, url: url, attr:attr, callback:callback)
                
            case .appMetaDataDownloaded(attr: let attr, dft: let dft):
                self?.downloadCompleted(dft: dft, url: nil, attr:attr, callback:callback)

            case .masterVersionUpdate:
                // Need to start all over again.
                self?.start(callback)
                
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
    
    private func downloadCompleted(dft: DownloadFileTracker, url: SMRelativeLocalURL?, attr:SyncAttributes, callback:((SyncServerError?)->())? = nil) {

        if delegate == nil {
            afterDownloadCompleted(dft: dft, callback: callback)
        }
        else {
#if DEBUG
            // Assuming that in testing self.delegate will not be nil.
            if testingDelegate == nil {
                normalDelegateAndAfterCalls(dft: dft, url: url, attr:attr, callback:callback)
            }
            else {
                Thread.runSync(onMainThread: {
                    var fileOperation: Bool = false
                    CoreData.sessionNamed(Constants.coreDataName).performAndWait() {
                        fileOperation = dft.operation == .file
                    }
                    
                    if fileOperation {
                        self.testingDelegate!.singleFileDownloadComplete(url: url!, attr: attr) {
                            self.afterDownloadCompleted(dft: dft, callback: callback)
                        }
                    }
                })
            }
#else
            normalDelegateAndAfterCalls(dft: dft, url: url, attr:attr, callback:callback)
#endif
        }
    }
    
    func normalDelegateAndAfterCalls(dft: DownloadFileTracker, url: SMRelativeLocalURL?, attr:SyncAttributes, callback:((SyncServerError?)->())? = nil) {
    
        var operation: FileTracker.Operation!
        var conflictingContent: ServerContentType = .appMetaData
        
        CoreData.sessionNamed(Constants.coreDataName).performAndWait() {
            operation = dft.operation
            
            if let url = url {
                if dft.appMetaData == nil {
                    conflictingContent = .file(url)
                }
                else {
                    conflictingContent = .both(downloadURL: url)
                }
            }
        }
        
        Thread.runSync(onMainThread: {[unowned self] in
            ConflictManager.handleAnyContentDownloadConflict(attr: attr, content: conflictingContent, delegate: self.delegate!) { ignoreDownload in
            
                if ignoreDownload == nil {
                    // Not 100% sure we're running on main thread-- its possible that the client didn't call the completion on the main thread.
                    Thread.runSync(onMainThread: {
                        switch operation! {
                        case .file:
                            self.delegate!.syncServerSingleFileDownloadComplete(url: url!, attr: attr)
                        case .appMetaData:
                            self.delegate!.syncServerAppMetaDataDownloadComplete(attr: attr)
                        case .deletion:
                            assert(false)
                        }
                    })
                }
                else {
                    Log.msg("ignoreDownload not nil")
                }
                
                DispatchQueue.global(qos: .default).sync {
                    self.afterDownloadCompleted(dft: dft, callback: callback)
                }
            }
        })
    }
    
    func afterDownloadCompleted(dft: DownloadFileTracker, callback:((SyncServerError?)->())? = nil) {
        CoreData.sessionNamed(Constants.coreDataName).performAndWait() {
            Directory.session.updateAfterDownloading(downloads: [dft])
        
            // 9/16/17; We're doing downloads in an eventually consistent manner. Remove the DownloadFileTracker-- we don't want to repeat this download. See http://www.spasticmuffin.biz/blog/2017/09/15/making-downloads-more-flexible-in-the-syncserver/
            CoreData.sessionNamed(Constants.coreDataName).remove(dft)
            CoreData.sessionNamed(Constants.coreDataName).saveContext()
        }
        
        // Recursively check for any next download. Using `async` so we don't consume extra space on the stack.
        DispatchQueue.global().async {
            self.start(callback)
        }
    }
    
    private func allDownloadsCompleted() {
        // Inform client via delegate of any download deletions.

        var deletions = [SyncAttributes]()
        var downloadDeletionDfts:[DownloadFileTracker]!

        CoreData.sessionNamed(Constants.coreDataName).performAndWait() {
            let dfts = DownloadFileTracker.fetchAll()
            downloadDeletionDfts = dfts.filter {$0.operation.isDeletion}

            downloadDeletionDfts.forEach { dft in
                let mimeType = MimeType(rawValue: dft.mimeType!)!

                let attr = SyncAttributes(fileUUID: dft.fileUUID, mimeType: mimeType, creationDate: dft.creationDate! as Date, updateDate: dft.updateDate! as Date)
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
            callback?(nil)
            
        case .allUploadsCompleted:
            self.doneUploads()
            
        case .error(let error):
            callback?(error)
        }
    }
    
    private func contentWasUploaded(attr:SyncAttributes?, uft: UploadFileTracker) {
        CoreData.sessionNamed(Constants.coreDataName).performAndWait() {
            switch uft.operation! {
            case .file:
                EventDesired.reportEvent(.singleFileUploadComplete(attr: attr!), mask: self.desiredEvents, delegate: self.delegate)
            case .appMetaData:
                EventDesired.reportEvent(.singleAppMetaDataUploadComplete(fileUUID: uft.fileUUID), mask: self.desiredEvents, delegate: self.delegate)
            case .deletion:
                assert(false)
            }
        }
        
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
                var fileUpload: Bool = false
                CoreData.sessionNamed(Constants.coreDataName).performAndWait() {
                    if uft.operation == .file {
                        fileUpload = true
                    }
                }
                
                if fileUpload {
                    self.testingDelegate!.syncServerSingleFileUploadCompleted(next: {
                        after()
                    })
                }
            })
        }
#else
        after()
#endif
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
                var errorResult:SyncServerError?

                CoreData.sessionNamed(Constants.coreDataName).performAndWait() {
                    // 4/18/18; Got a crash here during testing because `Upload.getHeadSyncQueue()` returned nil. How is that possible? An earlier test failed-- wonder if it could have "leaked" into a later test?
                    uploadQueue = Upload.getHeadSyncQueue()
                    if uploadQueue == nil {
                        errorResult = .generic("Nil result from getHeadSyncQueue.")
                        return
                    }
                    
                    fileUploads = uploadQueue.uploadFileTrackers.filter {$0.operation.isContents}
                }
                
                if errorResult != nil {
                    self.callback?(errorResult)
                    return
                }
                
                if fileUploads.count > 0 {
                    EventDesired.reportEvent(.fileUploadsCompleted(numberOfFiles: fileUploads.count), mask: self.desiredEvents, delegate: self.delegate)
                }
    
                CoreData.sessionNamed(Constants.coreDataName).performAndWait() { [unowned self] in
                    if fileUploads.count > 0 {
                        // Each of the DirectoryEntry's for the uploads needs to now be given its version, as uploaded. And appMetaData needs to be updated in directory if it has been updated on this upload.
                        fileUploads.forEach { uft in
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
                            
                            do {
                                try uft.remove()
                            } catch {
                                self.delegate?.syncServerErrorOccurred(error:
                                    .couldNotRemoveFileTracker)
                            }
                        }
                    }
                    
                    uploadDeletions = uploadQueue.uploadFileTrackers.filter {$0.operation.isDeletion}
                }

                if uploadDeletions.count > 0 {
                    EventDesired.reportEvent(.uploadDeletionsCompleted(numberOfFiles: uploadDeletions.count), mask: self.desiredEvents, delegate: self.delegate)
                }
                
                CoreData.sessionNamed(Constants.coreDataName).performAndWait() {
                    if uploadDeletions.count > 0 {
                        // Each of the DirectoryEntry's for the uploads needs to now be marked as deleted.
                        uploadDeletions.forEach { uft in
                            guard let uploadedEntry = DirectoryEntry.fetchObjectWithUUID(uuid: uft.fileUUID) else {
                                assert(false)
                                return
                            }

                            uploadedEntry.deletedOnServer = true
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
                }
                
                self.callback?(errorResult)
            }
        }
    }
}

