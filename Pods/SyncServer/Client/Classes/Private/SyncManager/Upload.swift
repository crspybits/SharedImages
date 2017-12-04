//
//  Upload.swift
//  SyncServer
//
//  Created by Christopher Prince on 2/28/17.
//
//

import Foundation
import SMCoreLib
import SyncServer_Shared

class Upload {
    static let session = Upload()
    var cloudFolderName:String!
    var deviceUUID:String!
    private var completion:((NextCompletion)->())?
    
    private init() {
    }
    
    enum NextResult {
    case started
    case noUploads
    case allUploadsCompleted
    case error(String)
    }
    
    enum NextCompletion {
    case fileUploaded(SyncAttributes)
    case uploadDeletion(fileUUID:String)
    case masterVersionUpdate
    case error(String)
    }
    
    // Starts upload of next file, if there is one. There should be no files uploading already. Only if .started is the NextResult will the completion handler be called. With a masterVersionUpdate response for NextCompletion, the MasterVersion Core Data object is updated by this method, and all the UploadFileTracker objects have been reset.
    func next(completion:((NextCompletion)->())?) -> NextResult {
        self.completion = completion
        
        var nextResult:NextResult!
        var masterVersion:MasterVersionInt!
        var nextToUpload:UploadFileTracker!
        var uploadQueue:UploadQueue!
        var deleteOnServer:Bool!
        
        CoreData.sessionNamed(Constants.coreDataName).performAndWait() {
            uploadQueue = Upload.getHeadSyncQueue()
            guard uploadQueue != nil else {
                nextResult = .noUploads
                return
            }
            
            let alreadyUploading =
                uploadQueue.uploadFileTrackers.filter {$0.status == .uploading}
            guard alreadyUploading.count == 0 else {
                let message = "Already uploading a file!"
                Log.error(message)
                nextResult = .error(message)
                return
            }

            nextToUpload = uploadQueue.nextUpload()
            guard nextToUpload != nil else {
                nextResult = .allUploadsCompleted
                return
            }

            nextToUpload.status = .uploading
            deleteOnServer = nextToUpload.deleteOnServer
            
            masterVersion = Singleton.get().masterVersion
            
            do {
                try CoreData.sessionNamed(Constants.coreDataName).context.save()
            } catch (let error) {
                nextResult = .error("\(error)")
            }
        }
        
        guard nextResult == nil else {
            return nextResult!
        }
        
        if deleteOnServer! {
            return uploadDeletion(nextToUpload:nextToUpload, uploadQueue:uploadQueue, masterVersion:masterVersion)
        }
        else {
            return uploadFile(nextToUpload: nextToUpload, uploadQueue: uploadQueue, masterVersion: masterVersion)
        }
    }
    
    private func uploadDeletion(nextToUpload:UploadFileTracker, uploadQueue:UploadQueue, masterVersion:MasterVersionInt) -> NextResult {

        // We need to figure out the current file version for the file we are deleting: Because, as explained in [1] in SyncServer.swift, we didn't establish the file version we were deleting earlier.
        
        var fileToDelete:ServerAPI.FileToDelete!
        
        var nextResult:NextResult?
        CoreData.sessionNamed(Constants.coreDataName).performAndWait() {
            let entry = DirectoryEntry.fetchObjectWithUUID(uuid: nextToUpload.fileUUID)
            if entry == nil {
                nextResult = .error("Could not find fileUUID: \(nextToUpload.fileUUID)")
                return
            }
            
            if entry!.fileVersion == nil {
                nextResult = .error("File version for fileUUID: \(nextToUpload.fileUUID) was nil!")
                return
            }
            
            fileToDelete = ServerAPI.FileToDelete(fileUUID: nextToUpload.fileUUID, fileVersion: entry!.fileVersion!)
        }
        
        guard nextResult == nil else {
            return nextResult!
        }
        
        ServerAPI.session.uploadDeletion(file: fileToDelete, serverMasterVersion: masterVersion) { (uploadDeletionResult, error) in
        
            guard error == nil else {
                CoreData.sessionNamed(Constants.coreDataName).performAndWait() {
                    nextToUpload.status = .notStarted
                    
                    // We already have an error, not going to worry about handling one with saveContext.
                    CoreData.sessionNamed(Constants.coreDataName).saveContext()
                }
                
                let message = "Error: \(String(describing: error))"
                Log.error(message)
                self.completion?(.error(message))
                return
            }
            
            switch uploadDeletionResult! {
            case .success:
                var completionResult:NextCompletion?
                CoreData.sessionNamed(Constants.coreDataName).performAndWait() {
                    nextToUpload.status = .uploaded
                    
                    do {
                        try CoreData.sessionNamed(Constants.coreDataName).context.save()
                    } catch (let error) {
                        completionResult = .error("\(error)")
                        return
                    }
                    
                    completionResult = .uploadDeletion(fileUUID: nextToUpload.fileUUID)
                }

                self.completion?(completionResult!)
                
            case .serverMasterVersionUpdate(let masterVersionUpdate):
                var completionResult:NextCompletion?
                CoreData.sessionNamed(Constants.coreDataName).performAndWait() {
                    // Simplest method for now: Mark all uft's as .notStarted
                    // TODO: *4* This could be better-- performance-wise, it doesn't make sense to do all the uploads over again.
                    _ = uploadQueue.uploadFileTrackers.map { uft in
                        uft.status = .notStarted
                    }

                    Singleton.get().masterVersion = masterVersionUpdate
                    
                    do {
                        try CoreData.sessionNamed(Constants.coreDataName).context.save()
                    } catch (let error) {
                        completionResult = .error("\(error)")
                        return
                    }
                    
                    completionResult = .masterVersionUpdate
                }
                
                self.completion?(completionResult!)
            }
        }
        
        return .started
    }
    
    private func uploadFile(nextToUpload:UploadFileTracker, uploadQueue:UploadQueue,masterVersion:MasterVersionInt) -> NextResult {
    
        var file:ServerAPI.File!
        CoreData.sessionNamed(Constants.coreDataName).performAndWait() {
            file = ServerAPI.File(localURL: nextToUpload.localURL! as URL!, fileUUID: nextToUpload.fileUUID, mimeType: nextToUpload.mimeType, cloudFolderName: self.cloudFolderName, deviceUUID:self.deviceUUID, appMetaData: nextToUpload.appMetaData, fileVersion: nextToUpload.fileVersion)
        }
        
        ServerAPI.session.uploadFile(file: file, serverMasterVersion: masterVersion) { (uploadResult, error) in
        
            guard error == nil else {
                CoreData.sessionNamed(Constants.coreDataName).performAndWait() {
                    nextToUpload.status = .notStarted
                    
                    // Already have an error, not going to worry about reporting one for saveContext.
                    CoreData.sessionNamed(Constants.coreDataName).saveContext()
                }
                
                /* TODO: *0* Need to deal with this error:
                    1) Do retry(s)
                    2) Fail if retries don't work and put the SyncServer client interface into an error state.
                    3) Deal with other, similar, errors too, in a similar way.
                */
                let message = "Error: \(String(describing: error))"
                Log.error(message)
                self.completion?(.error(message))
                return
            }
 
            switch uploadResult! {
            case .success(sizeInBytes: _):
                var completionResult:NextCompletion?
                CoreData.sessionNamed(Constants.coreDataName).performAndWait() {
                    nextToUpload.status = .uploaded
                    
                    do {
                        try CoreData.sessionNamed(Constants.coreDataName).context.save()
                    } catch (let error) {
                        completionResult = .error("\(error)")
                        return
                    }

                    let attr = SyncAttributes(fileUUID: nextToUpload.fileUUID, mimeType:nextToUpload.mimeType!)
                    completionResult = .fileUploaded(attr)
                }
                
                self.completion?(completionResult!)

            case .serverMasterVersionUpdate(let masterVersionUpdate):
                var completionResult:NextCompletion?
                CoreData.sessionNamed(Constants.coreDataName).performAndWait() {
                    // Simplest method for now: Mark all uft's as .notStarted
                    // TODO: *4* This could be better-- performance-wise, it doesn't make sense to do all the uploads over again.
                    _ = uploadQueue.uploadFileTrackers.map { uft in
                        uft.status = .notStarted
                    }

                    Singleton.get().masterVersion = masterVersionUpdate
                    
                    do {
                        try CoreData.sessionNamed(Constants.coreDataName).context.save()
                    } catch (let error) {
                        completionResult = .error("\(error)")
                        return
                    }
                    
                    completionResult = .masterVersionUpdate
                }
                
                self.completion?(completionResult!)
            }
        }
        
        return .started
    }
    
    enum DoneUploadsCompletion {
    case doneUploads(numberTransferred: Int64)
    case masterVersionUpdate
    case error(String)
    }
    
    func doneUploads(completion:((DoneUploadsCompletion)->())?) {
        var masterVersion:MasterVersionInt!
        CoreData.sessionNamed(Constants.coreDataName).performAndWait() {
            masterVersion = Singleton.get().masterVersion
        }
        
        ServerAPI.session.doneUploads(serverMasterVersion: masterVersion) { (result, error) in
            guard error == nil else {
                completion?(.error("\(String(describing: error))"))
                return
            }

            switch result! {
            case .success(numberUploadsTransferred: let numberTransferred):
                var completionResult:DoneUploadsCompletion?
                CoreData.sessionNamed(Constants.coreDataName).performAndWait() {
                    // Master version was incremented on the server as part of normal doneUploads operation. Update ours locally.
                    Singleton.get().masterVersion = masterVersion + 1
                    
                    do {
                        try CoreData.sessionNamed(Constants.coreDataName).context.save()
                    } catch (let error) {
                        completionResult = .error("\(error)")
                        return
                    }
                    
                    completionResult = .doneUploads(numberTransferred: numberTransferred)
                }
                
                completion?(completionResult!)
                
            case .serverMasterVersionUpdate(let masterVersionUpdate):
                var completionResult:DoneUploadsCompletion?
                CoreData.sessionNamed(Constants.coreDataName).performAndWait() {
                    guard let uploadQueue = Upload.getHeadSyncQueue() else {
                        completionResult = .error("Failed on getHeadSyncQueue")
                        return
                    }
                    
                    // Simplest method for now: Mark all uft's as .notStarted
                    // TODO: *4* This could be better-- performance-wise, it doesn't make sense to do all the uploads over again.
                    _ = uploadQueue.uploadFileTrackers.map { uft in
                        uft.status = .notStarted
                    }

                    Singleton.get().masterVersion = masterVersionUpdate
                    
                    do {
                        try CoreData.sessionNamed(Constants.coreDataName).context.save()
                    } catch (let error) {
                        completionResult = .error("\(error)")
                        return
                    }
                                        
                    completionResult = .masterVersionUpdate
                }
                
                completion?(completionResult!)
            }
        }
    }
}
