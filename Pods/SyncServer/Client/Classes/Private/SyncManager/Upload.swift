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
    var desiredEvents:EventDesired!
    weak var delegate:SyncServerDelegate?
    
    static let session = Upload()
    var deviceUUID:String!
    private var completion:((NextCompletion)->())?
    
    private init() {
    }
    
    enum NextResult {
        case started
        case noOperation
        case noUploads
        case allUploadsCompleted
        case error(SyncServerError)
    }
    
    enum NextCompletion {
        case fileUploaded(SyncAttributes, uft: UploadFileTracker)
        case appMetaDataUploaded(uft: UploadFileTracker)
        case uploadDeletion(fileUUID:String)
        case sharingGroupCreated
        case userRemovedFromSharingGroup
        case masterVersionUpdate
        case error(SyncServerError)
    }
    
    // Starts upload of next file, if there is one. There should be no files uploading already. Only if .started is the NextResult will the completion handler be called. With a masterVersionUpdate response for NextCompletion, the MasterVersion Core Data object is updated by this method, and all the UploadFileTracker objects have been reset.
    func next(sharingGroupUUID: String, first: Bool = false, completion:((NextCompletion)->())?) -> NextResult {
        self.completion = completion
        
        var nextResult:NextResult!
        var masterVersion:MasterVersionInt!
        var nextToUpload:Tracker!
        var uploadQueue:UploadQueue!
        var operation: FileTracker.Operation!
        var numberContentUploads:Int!
        var numberUploadDeletions:Int!
        var numberSharingGroupOperations:Int!
        var uploadFileTracker: UploadFileTracker!
        var sharingGroupUploadTracker: SharingGroupUploadTracker!
        var sharingGroupOperation: SharingGroupUploadTracker.SharingGroupOperation!
        
        CoreDataSync.perform(sessionName: Constants.coreDataName) {
            uploadQueue = Upload.getHeadSyncQueue(forSharingGroupUUID: sharingGroupUUID)
            guard uploadQueue != nil else {
                nextResult = .noUploads
                return
            }
            
            numberContentUploads = uploadQueue.uploadFileTrackers.filter
                {$0.status == .notStarted && $0.operation.isContents}.count
            
            numberUploadDeletions = uploadQueue.uploadFileTrackers.filter
                {$0.status == .notStarted && $0.operation.isDeletion}.count
            
            numberSharingGroupOperations = uploadQueue.sharingGroupUploadTrackers.filter
                {$0.status == .notStarted}.count
            
            let alreadyUploading =
                uploadQueue.uploadFileTrackers.filter {$0.status == .uploading}
            guard alreadyUploading.count == 0 else {
                Log.error("Already uploading a file!")
                nextResult = .error(.alreadyUploadingAFile)
                return
            }
            
            nextToUpload = uploadQueue.nextUploadTracker()
            
            switch nextToUpload {
            case .none:
                nextResult = .allUploadsCompleted
                return
            case .some(let uft as UploadFileTracker):
                uft.status = .uploading
                uploadFileTracker = uft
            case .some(let sgut as SharingGroupUploadTracker):
                sgut.status = .uploading
                sharingGroupUploadTracker = sgut
                sharingGroupOperation = sgut.sharingGroupOperation
            default:
                assert(false)
                break
            }
            
            operation = nextToUpload.operation
            masterVersion = SharingEntry.masterVersionForUUID(sharingGroupUUID)
            if masterVersion == nil {
                nextResult = .error(.generic("Could not get master version!"))
                return
            }
            
            do {
                try CoreData.sessionNamed(Constants.coreDataName).context.save()
            } catch (let error) {
                nextResult = .error(.coreDataError(error))
            }
        } // end perform
        
        guard nextResult == nil else {
            return nextResult!
        }
        
        if first {
            EventDesired.reportEvent(.willStartUploads(numberContentUploads: UInt(numberContentUploads), numberUploadDeletions: UInt(numberUploadDeletions), numberSharingGroupOperatioms: UInt(numberSharingGroupOperations)), mask: desiredEvents, delegate: delegate)
        }
        
        switch operation! {
        case .file:
            return uploadFile(nextToUpload: uploadFileTracker, uploadQueue: uploadQueue, masterVersion: masterVersion)
            
        case .appMetaData:
            return uploadAppMetaData(nextToUpload: uploadFileTracker, uploadQueue: uploadQueue, masterVersion: masterVersion)
            
        case .deletion:
            return uploadDeletion(nextToUpload:uploadFileTracker, uploadQueue:uploadQueue, masterVersion:masterVersion)
            
        case .sharingGroup:
            switch sharingGroupOperation! {
            case .create:
                return createSharingGroup(nextToUpload: sharingGroupUploadTracker)
            case .update:
                return updateSharingGroup(nextToUpload: sharingGroupUploadTracker)
            case .removeUser:
                return removeUserFromSharingGroup(nextToUpload: sharingGroupUploadTracker, uploadQueue:uploadQueue, masterVersion: masterVersion)
            }
        }
    }
    
    private func removeUserFromSharingGroup(nextToUpload: SharingGroupUploadTracker, uploadQueue:UploadQueue, masterVersion: MasterVersionInt) -> NextResult {
        var sharingGroupUUID: String!

        CoreDataSync.perform(sessionName: Constants.coreDataName) {
            sharingGroupUUID = nextToUpload.sharingGroupUUID
        }
        
        ServerAPI.session.removeUserFromSharingGroup(sharingGroupUUID: sharingGroupUUID, masterVersion: masterVersion) { response in
            switch response {
            case .success(let result):
                if let masterVersionUpdate = result {
                    self.masterVersionUpdate(uploadQueue:uploadQueue, masterVersionUpdate: masterVersionUpdate, sharingGroupUUID: sharingGroupUUID)
                }
                else {
                    var completionResult:NextCompletion?

                    CoreDataSync.perform(sessionName: Constants.coreDataName) {
                        nextToUpload.status = .uploaded
                        
                        do {
                            try CoreData.sessionNamed(Constants.coreDataName).context.save()
                        } catch (let error) {
                            completionResult = .error(.coreDataError(error))
                            return
                        }
                        
                        completionResult = .userRemovedFromSharingGroup
                    }

                    self.completion?(completionResult!)
                }
            case .error(let error):
                self.uploadError(.otherError(error), nextToUpload: nextToUpload)
            }
        }
        
        return .started
    }
    
    private func updateSharingGroup(nextToUpload: SharingGroupUploadTracker) -> NextResult {
        var result: NextResult = .noOperation
        
        CoreDataSync.perform(sessionName: Constants.coreDataName) {
            // Delayed until we do the DoneUploads.
            nextToUpload.status = .delayed
            
            do {
                try CoreData.sessionNamed(Constants.coreDataName).context.save()
            } catch (let error) {
                result = .error(.coreDataError(error))
                return
            }
        }
        
        return result
    }
    
    private func createSharingGroup(nextToUpload: SharingGroupUploadTracker) -> NextResult {
        var sharingGroupUUID: String!
        var sharingGroupName: String?

        CoreDataSync.perform(sessionName: Constants.coreDataName) {
            sharingGroupUUID = nextToUpload.sharingGroupUUID
            sharingGroupName = nextToUpload.sharingGroupName
        }
        
        ServerAPI.session.createSharingGroup(sharingGroupUUID: sharingGroupUUID, sharingGroupName: sharingGroupName) { error in
        
            guard error == nil else {
                self.uploadError(.otherError(error!), nextToUpload: nextToUpload)
                return
            }
            
            var completionResult:NextCompletion?

            CoreDataSync.perform(sessionName: Constants.coreDataName) {
                nextToUpload.status = .uploaded
                
                do {
                    try CoreData.sessionNamed(Constants.coreDataName).context.save()
                } catch (let error) {
                    completionResult = .error(.coreDataError(error))
                    return
                }
                
                completionResult = .sharingGroupCreated
            }

            self.completion?(completionResult!)
        }
    
        return .started
    }
    
    private func uploadDeletion(nextToUpload:UploadFileTracker, uploadQueue:UploadQueue, masterVersion:MasterVersionInt) -> NextResult {

        // We need to figure out the current file version for the file we are deleting: Because, as explained in [1] in SyncServer.swift, we didn't establish the file version we were deleting earlier.
        
        var fileToDelete:ServerAPI.FileToDelete!
        var sharingGroupUUID:String!
        
        var nextResult:NextResult?
        CoreDataSync.perform(sessionName: Constants.coreDataName) {
            let entry = DirectoryEntry.fetchObjectWithUUID(uuid: nextToUpload.fileUUID)
            if entry == nil {
                nextResult = .error(.couldNotFindFileUUID(nextToUpload.fileUUID))
                return
            }
            
            if entry!.fileVersion == nil {
                nextResult = .error(.versionForFileWasNil(fileUUUID: nextToUpload.fileUUID))
                return
            }
            
            if entry!.sharingGroupUUID == nil {
                nextResult = .error(.noSharingGroupUUID)
                return
            }
            
            fileToDelete = ServerAPI.FileToDelete(fileUUID: nextToUpload.fileUUID, fileVersion: entry!.fileVersion!, sharingGroupUUID: nextToUpload.sharingGroupUUID!)
            sharingGroupUUID = nextToUpload.sharingGroupUUID
        }
        
        guard nextResult == nil else {
            return nextResult!
        }
        
        ServerAPI.session.uploadDeletion(file: fileToDelete, serverMasterVersion: masterVersion) {[weak self] (uploadDeletionResult, error) in
        
            guard error == nil else {
                self?.uploadError(.otherError(error!), nextToUpload: nextToUpload)
                return
            }
            
            switch uploadDeletionResult! {
            case .success:
                var completionResult:NextCompletion?
                CoreDataSync.perform(sessionName: Constants.coreDataName) {
                    nextToUpload.status = .uploaded
                    
                    do {
                        try CoreData.sessionNamed(Constants.coreDataName).context.save()
                    } catch (let error) {
                        completionResult = .error(.coreDataError(error))
                        return
                    }
                    
                    completionResult = .uploadDeletion(fileUUID: nextToUpload.fileUUID)
                }

                self?.completion?(completionResult!)
                
            case .serverMasterVersionUpdate(let masterVersionUpdate):
                self?.masterVersionUpdate(uploadQueue:uploadQueue, masterVersionUpdate: masterVersionUpdate, sharingGroupUUID: sharingGroupUUID)
            }
        }
        
        return .started
    }
    
    private func uploadAppMetaData(nextToUpload:UploadFileTracker, uploadQueue:UploadQueue, masterVersion:MasterVersionInt) -> NextResult {
    
        var directoryEntry:DirectoryEntry?
        var nextResult:NextResult?
        var fileUUID: String!
        var appMetaData:AppMetaData!
        var sharingGroupUUID: String!
        
        CoreDataSync.perform(sessionName: Constants.coreDataName) {
            // 1/11/18; Determing the version to upload immediately before the upload. See https://github.com/crspybits/SyncServerII/issues/12
            
            directoryEntry = DirectoryEntry.fetchObjectWithUUID(uuid: nextToUpload.fileUUID)
            guard directoryEntry != nil else {
                nextResult = .error(.couldNotFindFileUUID(nextToUpload.fileUUID))
                return
            }
            
            nextToUpload.appMetaDataVersion = directoryEntry!.appMetaDataVersionToUpload(appMetaDataUpdate: nextToUpload.appMetaData)
            
            do {
                try CoreData.sessionNamed(Constants.coreDataName).context.save()
            } catch (let error) {
                nextResult = .error(.coreDataError(error))
                return
            }
            
            appMetaData = AppMetaData(version: nextToUpload.appMetaDataVersion, contents: nextToUpload.appMetaData)
            fileUUID = nextToUpload.fileUUID
            
            // It's OK to use the sharing group id from the upload tracker-- since we've already made the decision about which sharing group we're uploading.
            sharingGroupUUID = nextToUpload.sharingGroupUUID
        } // end perform
        
        guard nextResult == nil else {
            return nextResult!
        }
        
        ServerAPI.session.uploadAppMetaData(appMetaData: appMetaData, fileUUID: fileUUID, serverMasterVersion: masterVersion, sharingGroupUUID: sharingGroupUUID) {[weak self] result in
            switch result {
            case .success(.success):
                var completionResult:NextCompletion?
                CoreDataSync.perform(sessionName: Constants.coreDataName) {
                    nextToUpload.status = .uploaded
                    
                    do {
                        try CoreData.sessionNamed(Constants.coreDataName).context.save()
                    } catch (let error) {
                        completionResult = .error(.coreDataError(error))
                        return
                    }
                    
                    completionResult = .appMetaDataUploaded(uft: nextToUpload)
                }
                
                self?.completion?(completionResult!)
            
            case .success(.serverMasterVersionUpdate(let masterVersionUpdate)):
                self?.masterVersionUpdate(uploadQueue: uploadQueue, masterVersionUpdate: masterVersionUpdate, sharingGroupUUID: sharingGroupUUID)

            case .error(let error):
                self?.uploadError(.otherError(error), nextToUpload: nextToUpload)
            }
        }
        
        return .started
    }
    
    private func uploadFileCompletion(nextToUpload: UploadFileTracker, creationDate: Date? = nil, updateDate: Date? = nil, gone: GoneReason? = nil) -> NextCompletion {
        var completionResult:NextCompletion!

        CoreDataSync.perform(sessionName: Constants.coreDataName) {
            nextToUpload.status = .uploaded
            nextToUpload.gone = gone

            do {
                try CoreData.sessionNamed(Constants.coreDataName).context.save()
            } catch (let error) {
                completionResult = .error(.coreDataError(error))
                return
            }
    
            let mimeType = MimeType(rawValue: nextToUpload.mimeType!)!
            
            if nextToUpload.sharingGroupUUID == nil {
                completionResult = .error(.noSharingGroupUUID)
                return
            }

            // 1/27/18; See [2] below.
            var attr = SyncAttributes(fileUUID: nextToUpload.fileUUID, sharingGroupUUID: nextToUpload.sharingGroupUUID!, mimeType:mimeType, creationDate: creationDate, updateDate: updateDate)
            
            attr.gone = gone
            
            // `nextToUpload.appMetaData` may be nil because the client isn't making a change to the appMetaData.
            var appMetaData:String?
            if let amd = nextToUpload.appMetaData {
                appMetaData = amd
            }
            else {
                // See if the directory entry has any appMetaData
                if let dirEnt = DirectoryEntry.fetchObjectWithUUID(uuid: nextToUpload.fileUUID), let amd = dirEnt.appMetaData {
                    appMetaData = amd
                }
            }
            
            attr.appMetaData = appMetaData
            completionResult = .fileUploaded(attr, uft: nextToUpload)
        } // end perform
        
        return completionResult
    }
    
    private func uploadFile(nextToUpload:UploadFileTracker, uploadQueue:UploadQueue, masterVersion:MasterVersionInt) -> NextResult {
        
        var file:ServerAPI.File!
        var nextResult:NextResult?
        var directoryEntry:DirectoryEntry?
        var undelete = false
        var sharingGroupUUID: String!
        
        CoreDataSync.perform(sessionName: Constants.coreDataName) {
            // 1/11/18; Determining the version to upload immediately before the upload. See https://github.com/crspybits/SyncServerII/issues/12
            
            directoryEntry = DirectoryEntry.fetchObjectWithUUID(uuid: nextToUpload.fileUUID)
            guard directoryEntry != nil else {
                nextResult = .error(.couldNotFindFileUUID(nextToUpload.fileUUID))
                return
            }
            
            // Establish versions for both the file and app meta data.
            if directoryEntry!.fileVersion == nil {
                nextToUpload.fileVersion = 0
            }
            else {
                nextToUpload.fileVersion = directoryEntry!.fileVersion! + 1
            }
            
            nextToUpload.appMetaDataVersion = directoryEntry!.appMetaDataVersionToUpload(appMetaDataUpdate: nextToUpload.appMetaData)
            
            // Are we undeleting the file?
            nextToUpload.uploadUndeletion = nextToUpload.uploadUndeletion ||
                (!directoryEntry!.deletedLocally && directoryEntry!.deletedOnServer)
            
            do {
                try CoreData.sessionNamed(Constants.coreDataName).context.save()
            } catch (let error) {
                nextResult = .error(.coreDataError(error))
                return
            }
            
            let appMetaData = AppMetaData(version: nextToUpload.appMetaDataVersion, contents: nextToUpload.appMetaData)
            
            let mimeType = MimeType(rawValue: nextToUpload.mimeType!)!
            file = ServerAPI.File(localURL: nextToUpload.localURL as URL?, fileUUID: nextToUpload.fileUUID, fileGroupUUID: nextToUpload.fileGroupUUID, sharingGroupUUID: nextToUpload.sharingGroupUUID, mimeType: mimeType, deviceUUID:self.deviceUUID, appMetaData: appMetaData, fileVersion: nextToUpload.fileVersion, checkSum: nextToUpload.checkSum!)
            
            undelete = nextToUpload.uploadUndeletion
            sharingGroupUUID = nextToUpload.sharingGroupUUID
        } // end perform
        
        guard nextResult == nil else {
            return nextResult!
        }

        ServerAPI.session.uploadFile(file: file, serverMasterVersion: masterVersion, undelete: undelete) {[weak self] (uploadResult, error) in
        
            guard error == nil else {
                self?.uploadError(error!, nextToUpload: nextToUpload)
                return
            }
 
            switch uploadResult! {
            case .success(creationDate: let creationDate, updateDate: let updateDate):
                var completionResult:NextCompletion?
                completionResult = self?.uploadFileCompletion(nextToUpload: nextToUpload, creationDate: creationDate, updateDate: updateDate)
                self?.completion?(completionResult!)

            case .serverMasterVersionUpdate(let masterVersionUpdate):
                self?.masterVersionUpdate(uploadQueue: uploadQueue, masterVersionUpdate: masterVersionUpdate, sharingGroupUUID: sharingGroupUUID)
            case .gone (let goneReason):                
                // We're not treating "gone" as an error-- because I want to push up "gone" to the client app, and not retain an UploadFileTracker in the SyncServer client. The client app needs to decide what to do when a file is "gone" on the server.
                var completionResult:NextCompletion!
                completionResult = self?.uploadFileCompletion(nextToUpload: nextToUpload, gone: goneReason)
                self?.completion?(completionResult)
            }
        }
        
        return .started
    }
    
    private func masterVersionUpdate(uploadQueue:UploadQueue, masterVersionUpdate: MasterVersionInt, sharingGroupUUID: String) {
        var completionResult:NextCompletion?
        CoreDataSync.perform(sessionName: Constants.coreDataName) {
            // Simplest method for now: Mark all upload trackers as .notStarted
            // TODO: *4* This could be better-- performance-wise, it doesn't make sense to do all the uploads over again.
            uploadQueue.uploadFileTrackers.forEach { uft in
                uft.status = .notStarted
            }
    
            /* [3] SGUT's are more complicated.
                a) creation of sharing group:
                    Cannot cause a master version update. If done, don't do again.
                b) sharing group update:
                    No problem if done > once.
                c) removal of user from sharing group:
                    Can cause a master version update. But will be the only thing in the queue. So, do again if caused a master version update.
            */
            uploadQueue.sharingGroupUploadTrackers.forEach { sgut in
                switch sgut.sharingGroupOperation {
                case .create:
                    break
                case .update:
                    sgut.status = .notStarted
                case .removeUser:
                    sgut.status = .notStarted
                }
            }

            guard let sharingEntry = SharingEntry.fetchObjectWithUUID(uuid: sharingGroupUUID), !sharingEntry.removedFromGroup else {
                completionResult = .error(.generic("Could not get Sharing Entry."))
                return
            }
            
            sharingEntry.masterVersion = masterVersionUpdate
            
            do {
                try CoreData.sessionNamed(Constants.coreDataName).context.save()
            } catch (let error) {
                completionResult = .error(.coreDataError(error))
                return
            }
            
            completionResult = .masterVersionUpdate
        }

        completion?(completionResult!)
    }
    
    private func uploadError(_ error: SyncServerError, nextToUpload:Tracker) {
        CoreDataSync.perform(sessionName: Constants.coreDataName) {
            if let uploadFileTracker = nextToUpload as? UploadFileTracker {
                uploadFileTracker.status = .notStarted
            }
            else if let sharingTracker = nextToUpload as? SharingGroupUploadTracker {
                sharingTracker.status = .notStarted
            }
            else {
                assert(false)
            }
            
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
        self.completion?(.error(error))
    }
    
    enum DoneUploadsCompletion {
        case doneUploads(numberTransferred: Int64)
        case masterVersionUpdate
        case error(SyncServerError)
    }
    
    func doneUploads(sharingGroupUUID: String, completion:((DoneUploadsCompletion)->())?) {
        var masterVersion:MasterVersionInt!
        var sharingEntry:SharingEntry!
        var sharingGroup:SyncServer.SharingGroup!
        var errorCheckingForSharingGroupUpdate = false
        var sharingGroupNameUpdate: String?
        var sharingGroupUpdate: SharingGroupUploadTracker?

        CoreDataSync.perform(sessionName: Constants.coreDataName) {
            sharingEntry = SharingEntry.fetchObjectWithUUID(uuid: sharingGroupUUID)
            guard !sharingEntry.removedFromGroup else {
                sharingEntry = nil
                return
            }
            
            sharingGroup = sharingEntry.toSharingGroup()
            masterVersion = sharingEntry.masterVersion
            
            // See if we need to do a sharing group update along with the DoneUploads.
            let uploadQueue = Upload.getHeadSyncQueue(forSharingGroupUUID: sharingGroupUUID)
            guard uploadQueue != nil else {
                errorCheckingForSharingGroupUpdate = true
                return
            }

            let updates = uploadQueue!.sharingGroupUploadTrackers.filter {$0.sharingGroupOperation == .update}
            if updates.count > 0 {
                if updates.count > 1 {
                    errorCheckingForSharingGroupUpdate = true
                    Log.error("More than one sharing group update in same queue!")
                    return
                }
                
                sharingGroupNameUpdate = updates[0].sharingGroupName
                sharingGroupUpdate = updates[0]
                sharingGroupUpdate!.status = .uploading
                
                do {
                    try CoreData.sessionNamed(Constants.coreDataName).context.save()
                } catch (let error) {
                    errorCheckingForSharingGroupUpdate = true
                    Log.error("Error saving change to sharing group: \(error)")
                    return
                }
            }
        }
        
        if sharingEntry == nil {
            completion?(.error(.generic("Could not get master version.")))
            return
        }
        
        if errorCheckingForSharingGroupUpdate {
            completion?(.error(.generic("There was an error checking for a sharing group name update.")))
            return
        }
        
        ServerAPI.session.doneUploads(serverMasterVersion: masterVersion, sharingGroupUUID: sharingGroupUUID, sharingGroupNameUpdate: sharingGroupNameUpdate) { (result, error) in
            guard error == nil else {
                completion?(.error(error!))
                return
            }

            switch result! {
            case .success(numberUploadsTransferred: let numberTransferred):
                var completionResult:DoneUploadsCompletion?
                CoreDataSync.perform(sessionName: Constants.coreDataName) {
                    // Master version was incremented on the server as part of normal doneUploads operation. Update ours locally.
                    sharingEntry.masterVersion += MasterVersionInt(1)
                    
                    // If we did a sharing group name update on the server, apply it locally so we're in sync on sharing group names. (And don't have to do another sync() to apply the update.
                    if let sharingGroupNameUpdate = sharingGroupNameUpdate {
                        sharingEntry.sharingGroupName = sharingGroupNameUpdate
                        sharingGroupUpdate!.status = .uploaded
                    }
                    
                    do {
                        try CoreData.sessionNamed(Constants.coreDataName).context.save()
                    } catch (let error) {
                        completionResult = .error(.coreDataError(error))
                        return
                    }
                    
                    completionResult = .doneUploads(numberTransferred: numberTransferred)
                }
                
                if let _ = sharingGroupNameUpdate {
                    EventDesired.reportEvent(
                        .sharingGroupUploadOperationCompleted(sharingGroup: sharingGroup, operation: .update), mask: self.desiredEvents, delegate: self.delegate)
                }
                
                completion?(completionResult!)
                
            case .serverMasterVersionUpdate(let masterVersionUpdate):
                var completionResult:DoneUploadsCompletion?
                var uploadQueue: UploadQueue!
                CoreDataSync.perform(sessionName: Constants.coreDataName) {
                    uploadQueue = Upload.getHeadSyncQueue(forSharingGroupUUID: sharingGroupUUID)
                    guard uploadQueue != nil else {
                        completionResult = .error(.generic("Failed on getHeadSyncQueue"))
                        return
                    }
                } // end perform
                
                if completionResult != nil {
                    completion?(completionResult!)
                    return
                }
                
                self.masterVersionUpdate(uploadQueue:uploadQueue, masterVersionUpdate: masterVersionUpdate, sharingGroupUUID: sharingGroupUUID)
            }
        }
    }
}

/* 1/27/18; [2]. For some reason, up until now, I'd been assigning the directory entry from the uft file version right here (at [2] above in the code):

    directoryEntry!.fileVersion = nextToUpload.fileVersion

    HOWEVER, the upload isn't actually done until the DoneUploads
    succeeds *after* the upload. I'm focused on this right now because I just got an error because of this. The situation went like this:
    
    1) A file upload occurred (device 1)
    2) Two successive DoneUploads occurred (device 2, and then device 1, for the same user data)
    3) The second DoneUploads (trying to complete the file upload in 1)) fails because of the master version update from the Device 2 DoneUploads
    4) Device 1 retries its file upload, which makes the attempt with file version 1 because the directory entry had been assigned version 0 already.
    5) That file upload failed with a server error "File is new, but file version being uploaded (Optional(1)) is not 0".

    We'd been doing that fileVersion update in [1] in SyncManager.swift previously, so should be safe in just removing the assignment here.
*/
