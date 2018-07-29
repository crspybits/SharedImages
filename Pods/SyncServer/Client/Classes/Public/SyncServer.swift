//
//  SyncServer.swift
//  SyncServer
//
//  Created by Christopher Prince on 2/23/17.
//
//

import Foundation
import SMCoreLib
import SyncServer_Shared

/// Synchronize files and app meta data with other instances of the same client app.
public class SyncServer {
    /// The singleton for this class.
    public static let session = SyncServer()
    
    private var syncOperating = false
    private var delayedSync = false
    private var stoppingSync = false
    
    private init() {
    }
    
    /// Enable reporting of only events desired by the client app.
    public var eventsDesired:EventDesired {
        set {
            SyncManager.session.desiredEvents = newValue
            ServerAPI.session.desiredEvents = newValue
            Download.session.desiredEvents = newValue
            Upload.session.desiredEvents = newValue
            SyncServerUser.session.desiredEvents = newValue
        }
        
        get {
            return SyncManager.session.desiredEvents
        }
    }
    
    /// The delegate enables operations such as file downloads & conflict resolution.
    public weak var delegate:SyncServerDelegate! {
        set {
            SyncManager.session.delegate = newValue
            ServerAPI.session.syncServerDelegate = newValue
            ServerNetworking.session.syncServerDelegate = newValue
            Download.session.delegate = newValue
            Upload.session.delegate = newValue
            Directory.session.delegate = newValue
            SyncServerUser.session.delegate = newValue
        }
        
        get {
            return SyncManager.session.delegate
        }
    }
    
    /**
     Put a call to this in your AppDelegate or other place early in the launch sequence of your app.
     
     - parameters:
       - withServerURL: URL for the SyncServerII server.
       - cloudFolderName: In the cloud storage service, the path of the directory/folder in which to put files. `cloudFolderName` is optional because it's only needed for some of the cloud storage services (e.g., Google Drive).
       - minimumServerVersion: The minimum SyncServerII server version needed by your app. Leave nil if your app doesn't have a specific server version requirement.
     */
    public func appLaunchSetup(withServerURL serverURL: URL, cloudFolderName:String?, minimumServerVersion:ServerVersion? = nil) {
        Log.msg("cloudFolderName: \(String(describing: cloudFolderName))")
        Log.msg("serverURL: \(serverURL.absoluteString)")
                
        // This seems a little hacky, but can't find a better way to get the bundle of the framework containing our model. I.e., "this" framework. Just using a Core Data object contained in this framework to track it down.
        // Without providing this bundle reference, I wasn't able to dynamically locate the model contained in the framework.
        let bundle = Bundle(for: NSClassFromString(Singleton.entityName())!)
        
        let coreDataSession = CoreData(options: [
            CoreDataModelBundle: bundle,
            CoreDataBundleModelName: "Client",
            CoreDataSqlliteBackupFileName: "~Client.sqlite",
            CoreDataSqlliteFileName: "Client.sqlite",
            CoreDataPrivateQueue: true,
            CoreDataLightWeightMigration: true
        ]);
        
        CoreData.registerSession(coreDataSession, forName: Constants.coreDataName)
        Migrations.session.run()

        Network.session().appStartup()
        ServerAPI.session.baseURL = serverURL.absoluteString
        
        // 12/31/17; I put this in as part of: https://github.com/crspybits/SharedImages/issues/36
        resetFileTrackers()
        
        ServerNetworking.session.minimumServerVersion = minimumServerVersion

        // Remember: `ServerNetworkingLoading` relies on Core Data, so this setup call must be after the CoreData setup.
        ServerNetworkingLoading.session.appLaunchSetup()
        
        // SyncServerUser sets up the delegate for the ServerAPI. Need to set it up early in the launch sequence.
        SyncServerUser.session.appLaunchSetup(cloudFolderName: cloudFolderName)
        
        // Debugging
        CoreDataSync.perform(sessionName: Constants.coreDataName) {
            let pendingUploads = UploadFileTracker.fetchAll()
            Log.msg("Upload file tracker count: \(pendingUploads.count)")
            pendingUploads.forEach { uft in
                Log.msg("Upload file tracker status: \(uft.status)")
            }
        }
    }
    
    /**
     For dealing with background uploading/downloading. Call this from the same named delegate method in your AppDelegate.
     */
    public func application(_ application: UIApplication, handleEventsForBackgroundURLSession identifier: String, completionHandler: @escaping () -> Void) {
        ServerNetworkingLoading.session.application(application, handleEventsForBackgroundURLSession: identifier, completionHandler: completionHandler)
    }
    
    /**
        ## Enqueue a local immutable file for subsequent upload.
        
        Immutable files are assumed to not change (at least until after the upload has completed). This immutable characteristic is not enforced by this class but needs to be enforced by the caller of this class.
     
        This operation survives app launches, as long as the call itself completes.
        
        If there are contents with the same uuid, which have been enqueued for upload (file upload or appMetaData upload) but not yet `sync`'ed, they will be replaced by this upload request. That is, if you want to do both a file upload and an appMetaData upload in the same sync, then set the SyncAttributes with the appMetaData, and use one of the file upload operations.
     
        This operation does not access the server, and thus runs quickly and synchronously.
     
        You can only set the fileGroupUUID (in the SyncAttributes) when the file is first uploaded.

        ### When uploading a file for the 2nd or more time ("multi-version upload"):
        1. the 2nd and following updates must have the same mimeType as the first version of the file.
        2. If the attr.appMetaData is given as nil, and an earlier version had non-nil appMetaData, then the nil appMetaData is ignored-- i.e., the existing app meta data is not set to nil.
     
        The sharingGroupId for a series of files up until a sync() operation must be the same. If you want to change to dealing with a different sharing group, you must call sync().
     
        `Warning`: If you indicate that the mime type is "text/plain", and you are using Google Drive and the text contains unusual characters, you may run into problems-- e.g., downloading the files may fail.
     
        - parameters:
            - localFile: URL for the file to upload.
            - withAttributes: Attributes of the file to upload.
     */
    public func uploadImmutable(localFile:SMRelativeLocalURL, withAttributes attr: SyncAttributes) throws {
        try upload(fileURL: localFile, withAttributes: attr)
    }
    
    /**
        A copy of the file is made, and that is used for uploading. The caller can then change their original and it doesn't affect the upload. The copy is removed after the upload completes. This operation proceeds like `uploadImmutable` otherwise.
    */
    public func uploadCopy(localFile:SMRelativeLocalURL, withAttributes attr: SyncAttributes) throws {
        try upload(fileURL: localFile, withAttributes: attr, copy: true)
    }
    
    private func upload(fileURL:SMRelativeLocalURL, withAttributes attr: SyncAttributes, copy:Bool = false) throws {
        var errorToThrow:Error?
        
        guard attr.mimeType != nil else {
            throw SyncServerError.noMimeType
        }
        
        CoreDataSync.perform(sessionName: Constants.coreDataName) {[weak self] in
            errorToThrow = self?.checkIfSameSharingGroup(sharingGroupId: attr.sharingGroupId)
            if errorToThrow != nil {
                return
            }
            
            var entry = DirectoryEntry.fetchObjectWithUUID(uuid: attr.fileUUID)
            
            var fileGroupUUID:String?
            
            if nil == entry {
                entry = (DirectoryEntry.newObject() as! DirectoryEntry)
                entry!.fileUUID = attr.fileUUID
                entry!.mimeType = attr.mimeType.rawValue
                entry!.fileGroupUUID = attr.fileGroupUUID
                entry!.sharingGroupId = attr.sharingGroupId
                fileGroupUUID = attr.fileGroupUUID
            }
            else {
                guard let entryMimeTypeString = entry!.mimeType,
                    let entryMimeType = MimeType(rawValue: entryMimeTypeString) else {
                    errorToThrow = SyncServerError.noMimeType
                    return
                }
                
                if attr.mimeType != entryMimeType {
                    Log.error("attr.mimeType: \(String(describing: attr.mimeType)); entryMimeType: \(entryMimeType); attr.fileUUID: \(String(describing: attr.fileUUID))")
                    errorToThrow = SyncServerError.mimeTypeOfFileChanged
                    return
                }
                
                if entry!.deletedLocally {
                    errorToThrow = SyncServerError.fileAlreadyDeleted
                    return
                }
                
                if let fileGroupUUID = attr.fileGroupUUID {
                    guard entry!.fileGroupUUID == fileGroupUUID else {
                        errorToThrow = SyncServerError.fileGroupUUIDChanged
                        return
                    }
                }
                
                // Make sure I've got a fileGroupUUID in the uft, if there is one, to deal with conflicts
                fileGroupUUID = entry!.fileGroupUUID
            }
            
            let newUft = UploadFileTracker.newObject() as! UploadFileTracker
            newUft.appMetaData = attr.appMetaData
            newUft.fileUUID = attr.fileUUID
            newUft.mimeType = attr.mimeType.rawValue
            newUft.sharingGroupId = attr.sharingGroupId
            newUft.uploadCopy = copy
            newUft.operation = .file
            newUft.fileGroupUUID = fileGroupUUID
            
            if copy {
                // Make a copy of the file
                guard let copyOfFileURL = FilesMisc.newTempFileURL() else {
                    errorToThrow = SyncServerError.couldNotCreateNewFile
                    return
                }
                
                do {
                    try FileManager.default.copyItem(at: fileURL as URL, to: copyOfFileURL as URL)
                } catch (let error) {
                    errorToThrow = SyncServerError.fileManagerError(error)
                    return
                }
                
                newUft.localURL = copyOfFileURL
            }
            else {
                newUft.localURL = fileURL
            }
            
            // The file version to upload will be determined immediately before the upload so not assigning the fileVersion property of `newUft` yet. See https://github.com/crspybits/SyncServerII/issues/12
            // Similarly, the appMetaData version will be determined immediately before the upload.
            
            errorToThrow = self?.tryToAddUploadFileTracker(attr: attr, newUft: newUft)
        } // end perform
        
        guard errorToThrow == nil else {
            throw errorToThrow!
        }
    }
    
    /**
        Enqueue an upload of changed app meta data for an existing file.
     
        ### Like the other uploads above:
        1. This operation survives app launches, as long as the call itself completes,
        2. This operation does not access the server, and thus runs quickly and synchronously, and
        3. If there is a file with the same uuid, which has been enqueued for upload (file contents or appMetaData) but not yet `sync`'ed, it will be replaced by this upload request.
     
        - parameters:
            - attr: These attributes must have non-nil `appMetaData`.
    */

    public func uploadAppMetaData(attr: SyncAttributes) throws {
        guard let _ = attr.appMetaData else {
            throw SyncServerError.badAppMetaData
        }

        // This doesn't really use the mimeType, but just for consistency.
        guard let mimeType = attr.mimeType else {
            throw SyncServerError.noMimeType
        }
        
        var errorToThrow:Error?

        CoreDataSync.perform(sessionName: Constants.coreDataName) {[weak self] in
            errorToThrow = self?.checkIfSameSharingGroup(sharingGroupId: attr.sharingGroupId)
            if errorToThrow != nil {
                return
            }
            
            // In part, this ensures you can't do an appMetaData upload as v0 of a file.
            guard let entry = DirectoryEntry.fetchObjectWithUUID(uuid: attr.fileUUID) else {
                errorToThrow = SyncServerError.couldNotFindFileUUID(attr.fileUUID)
                return
            }
            
            guard let entryMimeTypeString = entry.mimeType,
                let entryMimeType = MimeType(rawValue: entryMimeTypeString) else {
                errorToThrow = SyncServerError.noMimeType
                return
            }
            
            if mimeType != entryMimeType {
                Log.error("mimeType: \(mimeType); entryMimeType: \(entryMimeType); attr.fileUUID: \(String(describing: attr.fileUUID))")
                errorToThrow = SyncServerError.mimeTypeOfFileChanged
                return
            }
            
            if entry.deletedLocally {
                errorToThrow = SyncServerError.fileAlreadyDeleted
                return
            }
            
            if let fileGroupUUID = attr.fileGroupUUID {
                guard entry.fileGroupUUID == fileGroupUUID else {
                    errorToThrow = SyncServerError.fileGroupUUIDChanged
                    return
                }
            }
            
            let newUft = UploadFileTracker.newObject() as! UploadFileTracker
            newUft.appMetaData = attr.appMetaData
            newUft.fileUUID = attr.fileUUID
            newUft.mimeType = attr.mimeType.rawValue
            newUft.sharingGroupId = attr.sharingGroupId
            newUft.uploadCopy = false
            newUft.operation = .appMetaData
            
            // The appMetaData version will be determined immediately before the upload. The file version is not used in this case.
            
            errorToThrow = self?.tryToAddUploadFileTracker(attr: attr, newUft: newUft)
        } // end perform
        
        guard errorToThrow == nil else {
            throw errorToThrow!
        }
    }
    
    // Do this in a Core Data perform block.
    private func checkIfSameSharingGroup(sharingGroupId: SharingGroupId) -> Error? {
        var errorToThrow: Error?
        
        Synchronized.block(self) {
            do {
                let uploadFileTrackers = try Upload.pendingSync().uploadFileTrackers
                let result = uploadFileTrackers.filter {$0.sharingGroupId == sharingGroupId}
                if result.count != uploadFileTrackers.count {
                    errorToThrow = SyncServerError.sharingGroupIdInconsistent
                }
            } catch (let error) {
                errorToThrow = error
            }
        }
        
        return errorToThrow
    }
    
    // Do this in a Core Data perform block.
    private func tryToAddUploadFileTracker(attr:SyncAttributes, newUft: UploadFileTracker) -> Error? {
        var errorToThrow: Error?
        
        Synchronized.block(self) {
            do {
                try failIfPendingDeletion(fileUUID: attr.fileUUID)
                
                let result = try Upload.pendingSync().uploadFileTrackers.filter
                    {$0.fileUUID == attr.fileUUID}
                
                result.forEach { uft in
                    do {
                        try uft.remove()
                    } catch {
                        errorToThrow = SyncServerError.couldNotRemoveFileTracker
                    }
                }
                
                try Upload.pendingSync().addToUploadsOverride(newUft)
                try CoreData.sessionNamed(Constants.coreDataName).context.save()
            } catch (let error) {
                errorToThrow = error
            }
        }
        
        return errorToThrow
    }
    
    /**
        This  method enqueues an upload deletion operation. The operation persists across app launches. It is an error to try again later to upload, or delete the file referenced by this UUID. You can only delete files that are already known to the SyncServer (e.g., that you've uploaded).
     
        If there is a file with the same uuid, which has been enqueued for upload but not yet `sync`'ed, it will be removed.
     
        This operation does not access the server, and thus runs quickly and synchronously.
     
        This operation undoes its work if it throws an error.
     
        - parameters:
            - fileWithUUID: The UUID of the file to delete.
    */
    public func delete(fileWithUUID uuid:UUIDString) throws {
        try delete(filesWithUUIDs: [uuid])
    }
    
    /**
        As above, but you can give multiple UUIDs.
     
        - parameters:
            - filesWithUUIDs: The UUID of the files to delete.
    */
    public func delete(filesWithUUIDs uuids:[UUIDString]) throws {
        var errorToThrow:Error?
        
        CoreDataSync.perform(sessionName: Constants.coreDataName) {
            // 8/25/17; I added an undo manager to deal with queueing up the deletion of a series of files, and undoing if one of them fails.
            CoreData.sessionNamed(Constants.coreDataName).context.undoManager = UndoManager()

            do {
                for uuid in uuids {
                    try self.delete(uuid: uuid)
                }
            } catch (let error) {
                CoreData.sessionNamed(Constants.coreDataName).context.rollback()
                errorToThrow = error
            }
            
            if errorToThrow == nil {
                do {
                    try CoreData.sessionNamed(Constants.coreDataName).context.save()
                } catch (let error) {
                    CoreData.sessionNamed(Constants.coreDataName).context.rollback()
                    errorToThrow = error
                }
            }
            
            CoreData.sessionNamed(Constants.coreDataName).context.undoManager = nil
        }
        
        guard errorToThrow == nil else {
            throw errorToThrow!
        }
    }
    
    // This does not do a Core Data context save.
    private func delete(uuid:UUIDString) throws {
        // We must already know about this file in our local Directory.
        guard let entry = DirectoryEntry.fetchObjectWithUUID(uuid: uuid) else {
            throw SyncServerError.deletingUnknownFile
        }
        
        guard let sharingGroupId = entry.sharingGroupId else {
            throw SyncServerError.noSharingGroupId
        }
        
        if let errorToThrow = checkIfSameSharingGroup(sharingGroupId: sharingGroupId) {
            throw errorToThrow
        }

        guard !entry.deletedLocally else {
            throw SyncServerError.fileAlreadyDeleted
        }

        try failIfPendingDeletion(fileUUID: uuid)
        
        var errorToThrow:Error?

        Synchronized.block(self) {
            do {
                // Remove any upload for this UUID from the pendingSync queue.
                let pendingSync = try Upload.pendingSync().uploadFileTrackers.filter
                    {$0.fileUUID == uuid }
                pendingSync.forEach { uft in
                    do {
                        try uft.remove()
                    } catch {
                        errorToThrow = SyncServerError.couldNotRemoveFileTracker
                    }
                }
                
                // If we just removed any references to a new file, by removing the reference from pendingSync, then we're done.
                // TODO: *1* We need a little better locking of data here. I think it's possible an upload is concurrently happening, and we'll mess up here. i.e., I think there could be a race condition between uploads and this deletion process, and we haven't locked out the Core Data info sufficiently. We could end up in a situation with a recently uploaded file, and a file marked only-locally as deleted.
                if entry.fileVersion == nil {
                    let results = UploadFileTracker.fetchAll().filter {$0.fileUUID == uuid}
                    if results.count == 0 {
                        // Note that this file never actually made it to the server.
                        entry.deletedLocally = true
                        return
                    }
                }
                
                let newUft = UploadFileTracker.newObject() as! UploadFileTracker
                newUft.operation = .deletion
                newUft.fileUUID = uuid
                newUft.sharingGroupId = entry.sharingGroupId

                /* [1]: `entry.fileVersion` will be nil if we are in the process of uploading a new file. Which causes the following to fail:
                        newUft.fileVersion = entry.fileVersion
                    AND: In general, there can be any number of uploads queued and sync'ed prior to this upload deletion, which would mean we can't simply determine the version to delete at this point in time. It seems easiest to wait until the last possible moment to determine the file version we are deleting.
                */
                
                try Upload.pendingSync().addToUploadsOverride(newUft)
            } catch (let error) {
                errorToThrow = error
            }
        }
        
        guard errorToThrow == nil else {
            throw errorToThrow!
        }
    }
    
    // Check to see if there is a pending upload deletion with this UUID.
    private func failIfPendingDeletion(fileUUID: String) throws {
        let pendingUploadDeletions = UploadFileTracker.fetchAll().filter {$0.fileUUID == fileUUID && $0.operation.isDeletion }
        if pendingUploadDeletions.count > 0 {
            throw SyncServerError.fileQueuedForDeletion
        }
    }
    
    /**
        If no other `sync` is taking place, this will asynchronously do pending downloads, file uploads, and upload deletions for the given sharing group. If there is a `sync` currently taking place (for any sharing group), this closes the collection of uploads/deletions queued, and will wait until after the current sync is done, and try again.
     
        If a stopSync is currently pending, then this call will be ignored.
     
        Non-blocking in all cases.
    */
    public func sync(sharingGroupId: SharingGroupId) {
        sync(sharingGroupId:sharingGroupId, completion:nil)
    }
    
    func sync(sharingGroupId: SharingGroupId, completion:(()->())?) {
        var doStart = true
        
        Synchronized.block(self) {
            // If we're in the process of stopping synchronization, ignore sync attempts.
            if stoppingSync {
                doStart = false
                return
            }
            
            // 5/24/18; The positioning of this block of code has given me some consternation. It *must* come before block [2] below-- because the `sync` operation must do a sync, and `movePendingSyncToSynced` is core to what the sync operation is-- any delay aspect just doesn't trigger it with the `start` operation. HOWEVER, I found that https://github.com/crspybits/SharedImages/issues/101 was due to a deadlock of performAndWait calls. So, I've ended up with a rather different means of dealing with Core Data synchronization in the form of `CoreDataSync` used below.
            CoreDataSync.perform(sessionName: Constants.coreDataName) {
                // TODO: *0* Need an error reporting mechanism. These should not be `try!`
                if try! Upload.pendingSync().uploadFileTrackers.count > 0  {
                    try! Upload.movePendingSyncToSynced()
                }
            }
            
            // [2]
            if syncOperating {
                EventDesired.reportEvent(.syncDelayed, mask: self.eventsDesired, delegate: self.delegate)
                delayedSync = true
                doStart = false
            }
            else {
                syncOperating = true
            }
        }
        
        if doStart {
            start(sharingGroupId: sharingGroupId, completion: completion)
        }
    }
    
    /** Stop an ongoing sync operation. This will stop the operation at the next "natural" stopping point. E.g., after a next download completes. No effect if no ongoing sync operation. Any delayed sync is cancelled.
    */
    public func stopSync() {
        Synchronized.block(self) {
            if syncOperating {
                delayedSync = false
                stoppingSync = true
                SyncManager.session.stopSync = true
            }
        }
    }
    
    /**
        Operates synchronously and quickly. A file must have already been uploaded (or downloaded) for you to be able to get its attributes. It is an error to call this for a uuid that doesn't yet exist, or for one that has already been deleted.
    
        - parameters:
            - forUUID: The UUID of the file to get attributes for.
    */
    public func getAttributes(forUUID uuid: String) throws -> SyncAttributes {
        var error:Error?
        var attr: SyncAttributes?
        
        CoreDataSync.perform(sessionName: Constants.coreDataName) {
            guard let entry = DirectoryEntry.fetchObjectWithUUID(uuid: uuid) else {
                error = SyncServerError.getAttributesForUnknownFile
                return
            }
            
            guard !entry.deletedLocally else {
                error = SyncServerError.fileAlreadyDeleted
                return
            }
            
            attr = entry.attr
        }
        
        if let error = error {
            throw error
        }
        
        return attr!
    }
    
    /// Object returned by call to `getStats`.
    public struct Stats {
        /// file downloads and/or appMetaData downloads.
        public let contentDownloadsAvailable:Int
        
        public let downloadDeletionsAvailable:Int
    }
    
    /**
        This information is for general purpose use (e.g., UI) and makes no guarantees about files to be downloaded when you next do a `sync` operation.
    
        - parameters:
            - completion: Gives stats about downloads that are currently available; gives nil if there was an error.
    */
    public func getStats(sharingGroupId: SharingGroupId, completion:@escaping (Stats?)->()) {
        Download.session.onlyCheck(sharingGroupId: sharingGroupId) { onlyCheckResult in
            switch onlyCheckResult {
            case .error(let error):
                Log.error("Error on Download onlyCheck: \(error)")
                completion(nil)
            
            case .checkResult(downloadSet: let downloadSet, _):
                let stats = Stats(contentDownloadsAvailable: downloadSet.downloadFiles.count + downloadSet.downloadAppMetaData.count, downloadDeletionsAvailable: downloadSet.downloadDeletions.count)
                completion(stats)
            }
        }
    }
    
    /// The type of reset to perform with a call to `reset`.
    public enum ResetType {
        /// Resets only persistent data that tracks uploads and downloads in the SyncServer. Makes no server calls. This should not be required, but sometimes is useful due to bugs or crashes in the SyncServer and could be required.
        case tracking
        
        /// A powerful operation. Permanently removes all local/cached metadata known by the client interface. E.g., metadata about files that you have previously uploaded. It makes no server calls. This is similar to deleting and re-installing the app-- except that it does not delete the files referenced by the meta data. You must keep track of files and, if desired, delete them.
        case all
    }
    
    /**
        Does a reset of local (not server) tracking data.
     
        Doesn't sign the user out or require that the user is signed in.
     
        This method may only be called when the client is not doing any sync operations.
     
        - parameters:
            - type: type of reset to perform.
    */
    public func reset(type: ResetType) throws {
        var result:SyncServerError?
        
        Synchronized.block(self) {
            if syncOperating {
                result = .syncIsOperating
            }
            else {
                do {
                    try SyncServer.resetMetaData(type: type)
                } catch (let error) {
                    result = (error as! SyncServerError)
                }
            }
        }
        
        if let result = result {
            throw result
        }
    }
    
    // Separated out of the `reset` method above to use this one for testing.
    internal static func resetMetaData(type: ResetType = .all) throws /* SyncServerError */ {
        var result:SyncServerError?

        CoreDataSync.perform(sessionName: Constants.coreDataName) {
            switch type {
            case .all:
                DirectoryEntry.removeAll()
                fallthrough
                
            case .tracking:
                DownloadFileTracker.removeAll()
                UploadFileTracker.removeAll()
                UploadQueue.removeAll()
                UploadQueues.removeAll()
                Singleton.removeAll()
                NetworkCached.removeAll()
                DownloadContentGroup.removeAll()
            }
            
            do {
                try CoreData.sessionNamed(Constants.coreDataName).context.save()
            } catch (let error) {
                result = .coreDataError(error)
            }
        }
        
        if let result = result {
            throw result
        }
    }
    
    static let trailingMarker = "*************** logAllTracking: Ends ***************"
    
    /**
        Logs information about all tracking internal meta data.
    
        - parameter:
            - completion: When the completion handler is called, the file data logged should be present in persistent storage. Runs asynchronously on the main thread.
    */
    public func logAllTracking(completion: (()->())? = nil) {
        Log.msg("*************** Starts: logAllTracking ***************")
        CoreDataSync.perform(sessionName: Constants.coreDataName) {
            DownloadContentGroup.printAll()
            DownloadFileTracker.printAll()
            UploadFileTracker.printAll()
            UploadQueue.printAll()
            UploadQueues.printAll()
            Singleton.printAll()
            NetworkCached.printAll()
        }
        Log.msg(SyncServer.trailingMarker)
        
        // See also https://stackoverflow.com/questions/50311546/ios-flush-all-output-files/50311616
        if let completion = completion {
            DispatchQueue.main.async {
                completion()
            }
        }
    }
    
    /// Return result from `localConsistencyCheck`.
    public struct LocalConsistencyResults {
        /// Files not known to the caller of this interface and known to be deleted by this SyncServer interface.
        public let clientMissingAndDeleted:Set<UUIDString>!
        
        /// Files not known to the caller of this interface and known to be not deleted by this SyncServer interface.
        public let clientMissingNotDeleted:Set<UUIDString>!
        
        /// Files not tracked or otherwise known about by this SyncServer interface.
        public let directoryMissing:Set<UUIDString>!
    }
    
    /**
        Performs a similar operation to a file system consistency or integrity check. Only operates if not currently synchronizing. Suitable for running at app startup.
    
        - parameters:
            - clientFiles: UUID's of files known to the client.
    */
    public func localConsistencyCheck(clientFiles:[UUIDString]) throws -> LocalConsistencyResults? {
        var error: Error?
        var results:LocalConsistencyResults!
        
        Synchronized.block(self) {
            if !syncOperating {
                /* client: A, B, C
                    metadata: B, C, D
                    1) intersection= client intersect metadata (= B, C)
                    2) client - intersection = A
                    3) metadata - intersection = D
                */
                let client = Set(clientFiles)
                var directory = Set<UUIDString>()
                
                CoreDataSync.perform(sessionName: Constants.coreDataName) {
                    do {
                        let directoryEntries = try CoreData.sessionNamed(Constants.coreDataName).fetchAllObjects(withEntityName: DirectoryEntry.entityName()) as? [DirectoryEntry]
                        if directoryEntries != nil {
                            for entry in directoryEntries! {
                                if !entry.deletedLocally {
                                    directory.insert(entry.fileUUID!)
                                }
                            }
                        }
                    } catch (let exception) {
                        error = exception
                    }
                }
                
                if error != nil {
                    return
                }
                
                let intersection = client.intersection(directory)
                
                // Elements from client that are missing in the directory
                let clientMissing = client.subtracting(intersection)
                var clientMissingNotDeleted = Set<UUIDString>()
                
                // Check to see if these are deleted from the directory
                CoreDataSync.perform(sessionName: Constants.coreDataName) {
                    for missing in clientMissing {
                        if let entry = DirectoryEntry.fetchObjectWithUUID(uuid: missing), !entry.deletedLocally {
                            clientMissingNotDeleted.insert(missing)
                        }
                    }
                }
                
                let clientMissingAndDeleted = clientMissing.subtracting(clientMissingNotDeleted)
                
                // Elements in directory that are missing in client. At least some of these could be files that were deleted on the server before they were ever actually processed by the client.
                let directoryMissing = directory.subtracting(intersection)
                
                Log.msg("clientMissingAndDeleted: \(clientMissingAndDeleted)")
                Log.msg("clientMissingNotDeleted: \(clientMissingNotDeleted)")
                Log.msg("directoryMissing: \(directoryMissing)")
                results = LocalConsistencyResults(clientMissingAndDeleted: clientMissingAndDeleted, clientMissingNotDeleted: clientMissingNotDeleted, directoryMissing: directoryMissing)
            }
        }
                        
        if error != nil {
            throw error!
        }
        
        return results
    }
    
    private func start(sharingGroupId: SharingGroupId, completion:(()->())?) {
        EventDesired.reportEvent(.syncStarted, mask: self.eventsDesired, delegate: self.delegate)
        Log.msg("SyncServer.start")
        
        SyncManager.session.start(sharingGroupId: sharingGroupId, first: true) { error in
            if error != nil {
                Thread.runSync(onMainThread: {
                    self.delegate?.syncServerErrorOccurred(error: error!)
                })
                
                // There was an error. Not much point in continuing.
                Synchronized.block(self) {
                    self.delayedSync = false
                    self.syncOperating = false
                }
                
                self.resetFileTrackers()
                return
            }
            
            completion?()
            EventDesired.reportEvent(.syncDone, mask: self.eventsDesired, delegate: self.delegate)

            var doStart = false
            
            Synchronized.block(self) { [unowned self] in
                CoreDataSync.perform(sessionName: Constants.coreDataName) {
                    if !self.stoppingSync && (Upload.haveSyncQueue(forSharingGroupId: sharingGroupId) || self.delayedSync) {
                        self.delayedSync = false
                        doStart = true
                    }
                    else {
                        self.syncOperating = false
                    }
                }
                
                self.stoppingSync = false
            }
            
            if doStart {
                self.start(sharingGroupId: sharingGroupId, completion:completion)
            }
        }
    }

    private func resetFileTrackers() {
        CoreDataSync.perform(sessionName: Constants.coreDataName) {
            let dfts = DownloadFileTracker.fetchAll()
            dfts.forEach { dft in
                if dft.status == .downloading {
                    dft.status = .notStarted
                }
            }
            
            // Not sure how to report an error here...
            let ufts = UploadFileTracker.fetchAll()
            ufts.forEach(){ uft in
                if uft.status == .uploading {
                    uft.status = .notStarted
                }
            }
            
            let dcgs = DownloadContentGroup.fetchAll()
            dcgs.forEach { dcg in
                if dcg.status == .downloading {
                    dcg.status = .notStarted
                }
            }

            // Not sure how to report an error here...
            CoreData.sessionNamed(Constants.coreDataName).saveContext()
        }
    }

    // TODO: *2* This is incomplete. Needs more work.
    /// This is intended for development/debug only. This enables you do a consistency check between your local files and SyncServer meta data. Does a sync first to ensure files are synchronized.
    public func consistencyCheck(sharingGroupId: SharingGroupId, localFiles:[UUIDString], repair:Bool = false, completion:((Error?)->())?) {
        sync(sharingGroupId: sharingGroupId) {
            // TODO: *2* Check for errors in sync.
            Consistency.check(sharingGroupId: sharingGroupId, localFiles: localFiles, repair: repair, callback: completion)
        }
    }
}
