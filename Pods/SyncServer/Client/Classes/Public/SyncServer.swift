//
//  SyncServer.swift
//  SyncServer
//
//  Created by Christopher Prince on 2/23/17.
//
//

import Foundation
import SMCoreLib

public class SyncServer {
    public static let session = SyncServer()
    private var syncOperating = false
    private var delayedSync = false
    private var stoppingSync = false
    
    private init() {
    }
    
    public var eventsDesired:EventDesired {
        set {
            SyncManager.session.desiredEvents = newValue
            ServerAPI.session.desiredEvents = newValue
            Download.session.desiredEvents = newValue
            Upload.session.desiredEvents = newValue
        }
        
        get {
            return SyncManager.session.desiredEvents
        }
    }
    
    public weak var delegate:SyncServerDelegate? {
        set {
            SyncManager.session.delegate = newValue
            ServerAPI.session.syncServerDelegate = newValue
            Download.session.delegate = newValue
            Upload.session.delegate = delegate
        }
        
        get {
            return SyncManager.session.delegate
        }
    }
        
    public func appLaunchSetup(withServerURL serverURL: URL, cloudFolderName:String) {
        Log.msg("cloudFolderName: \(cloudFolderName)")
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
        
        Upload.session.cloudFolderName = cloudFolderName
        Network.session().appStartup()
        ServerAPI.session.baseURL = serverURL.absoluteString
        
        // 12/31/17; I put this in as part of: https://github.com/crspybits/SharedImages/issues/36
        resetFileTrackers()
        
        // Remember: `ServerNetworkingLoading` relies on Core Data, so this setup call must be after the CoreData setup.
        ServerNetworkingLoading.session.appLaunchSetup()
        
        // SyncServerUser sets up the delegate for the ServerAPI. Need to set it up early in the launch sequence.
        SyncServerUser.session.appLaunchSetup()
    }
    
    public func application(_ application: UIApplication, handleEventsForBackgroundURLSession identifier: String, completionHandler: @escaping () -> Void) {
        ServerNetworkingLoading.session.application(application, handleEventsForBackgroundURLSession: identifier, completionHandler: completionHandler)
    }
    
    // Enqueue a local immutable file for subsequent upload. Immutable files are assumed to not change (at least until after the upload has completed). This immutable characteristic is not enforced by this class but needs to be enforced by the caller of this class.
    // This operation survives app launches, as long as the the call itself completes. 
    // If there is a file with the same uuid, which has been enqueued for upload but not yet `sync`'ed, it will be replaced by the given file. 
    // This operation does not access the server, and thus runs quickly and synchronously.
    // When uploading a file for the 2nd or more time ("multi-version upload") the 2nd and following updates must have the same mimeType as the first version of the file.
    // Warning: If you indicate that the mime type is "text/plain", and you are using Google Drive and the text contains unusual characters, you may run into problems-- e.g., downloading the files may fail.
    public func uploadImmutable(localFile:SMRelativeLocalURL, withAttributes attr: SyncAttributes) throws {
        try upload(fileURL: localFile, withAttributes: attr)
    }
    
    private func upload(fileURL:SMRelativeLocalURL, withAttributes attr: SyncAttributes) throws {
        var errorToThrow:Error?
        
        CoreData.sessionNamed(Constants.coreDataName).performAndWait() {
            var entry = DirectoryEntry.fetchObjectWithUUID(uuid: attr.fileUUID)
            
            if nil == entry {
                entry = (DirectoryEntry.newObject() as! DirectoryEntry)
                entry!.fileUUID = attr.fileUUID
                entry!.mimeType = attr.mimeType
            }
            else {
                if attr.mimeType != entry!.mimeType {
                    errorToThrow = SyncServerError.mimeTypeOfFileChanged
                    return
                }
                
                if entry!.deletedOnServer {
                    errorToThrow = SyncServerError.fileAlreadyDeleted
                    return
                }
            }
            
            let newUft = UploadFileTracker.newObject() as! UploadFileTracker
            newUft.localURL = fileURL
            newUft.appMetaData = attr.appMetaData
            newUft.fileUUID = attr.fileUUID
            newUft.mimeType = attr.mimeType
            
            // The file version to upload will be determined immediately before the upload so not assigning the fileVersion property of `newUft` yet. See https://github.com/crspybits/SyncServerII/issues/12

            Synchronized.block(self) {
                // Has this file UUID been added to `pendingSync` already? i.e., Has the client called `uploadImmutable`, then a little later called `uploadImmutable` again, with the same uuid, all without calling `sync`-- so, we don't have a new file version because new file versions only occur once the upload hits the server.
                do {
                    let result = try Upload.pendingSync().uploadFileTrackers.filter
                        {$0.fileUUID == attr.fileUUID}
                    
                    if result.count > 0 {
                        _ = result.map { uft in
                            CoreData.sessionNamed(Constants.coreDataName).remove(uft)
                        }
                    }
                    
                    try Upload.pendingSync().addToUploadsOverride(newUft)
                    try CoreData.sessionNamed(Constants.coreDataName).context.save()
                } catch (let error) {
                    errorToThrow = error
                }
            }
        }
        
        guard errorToThrow == nil else {
            throw errorToThrow!
        }
    }
    
    // The following two methods enqueue upload deletion operation(s). The operation(s) persists across app launches. It is an error to try again later to upload, or delete the file(s) referenced by the(se) UUID. You can only delete files that are already known to the SyncServer (e.g., that you've uploaded).
    // If there is a file with the same uuid, which has been enqueued for upload but not yet `sync`'ed, it will be removed.
    // These operations do not access the server, and thus run quickly and synchronously.
    // These operations undo their work if they throw errors.
    
    public func delete(fileWithUUID uuid:UUIDString) throws {
        try delete(filesWithUUIDs: [uuid])
    }
    
    public func delete(filesWithUUIDs uuids:[UUIDString]) throws {
        var errorToThrow:Error?
        
        CoreData.sessionNamed(Constants.coreDataName).performAndWait() {
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

        guard !entry.deletedOnServer else {
            throw SyncServerError.fileAlreadyDeleted
        }

        // Check to see if there is a pending upload deletion with this UUID.
        let pendingUploadDeletions = UploadFileTracker.fetchAll().filter {$0.fileUUID == uuid && $0.deleteOnServer }
        if pendingUploadDeletions.count > 0 {
            throw SyncServerError.fileQueuedForDeletion
        }
        
        var errorToThrow:Error?

        Synchronized.block(self) {
            do {
                // Remove any upload for this UUID from the pendingSync queue.
                let pendingSync = try Upload.pendingSync().uploadFileTrackers.filter
                    {$0.fileUUID == uuid }
                _ = pendingSync.map { uft in
                    CoreData.sessionNamed(Constants.coreDataName).remove(uft)
                }
                
                // If we just removed any references to a new file, by removing the reference from pendingSync, then we're done.
                // TODO: *1* We need a little better locking of data here. I think it's possible an upload is concurrently happening, and we'll mess up here. i.e., I think there could be a race condition between uploads and this deletion process, and we haven't locked out the Core Data info sufficiently. We could end up in a situation with a recently uploaded file, and a file marked only-locally as deleted.
                if entry.fileVersion == nil {
                    let results = UploadFileTracker.fetchAll().filter {$0.fileUUID == uuid}
                    if results.count == 0 {
                        // This is a slight mis-representation of terms. The file never actually made it to the server.
                        entry.deletedOnServer = true
                        return
                    }
                }
                
                let newUft = UploadFileTracker.newObject() as! UploadFileTracker
                newUft.deleteOnServer = true
                newUft.fileUUID = uuid
                
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
    
    // If no other `sync` is taking place, this will asynchronously do pending downloads, file uploads, and upload deletions. If there is a `sync` currently taking place, this will wait until after that is done, and try again. If a stopSync is currently pending, then this will be ignored.
    // Non-blocking in all cases.
    public func sync() {
        sync(completion:nil)
    }
    
    func sync(completion:(()->())?) {
        var doStart = true
        
        Synchronized.block(self) {
            // If we're in the process of stopping synchronizatoin, ignore sync attempts.
            if stoppingSync {
                doStart = false
                return
            }
            
            CoreData.sessionNamed(Constants.coreDataName).performAndWait() {
                // TODO: *0* Need an error reporting mechanism. These should not be `try!`
                if try! Upload.pendingSync().uploadFileTrackers.count > 0  {
                    try! Upload.movePendingSyncToSynced()
                }
            }
            
            if syncOperating {
                delayedSync = true
                doStart = false
            }
            else {
                syncOperating = true
            }
        }
        
        if doStart {
            start(completion: completion)
        }
    }
    
    // Stop an ongoing sync operation. This will stop the operation at the next "natural" stopping point. E.g., after a next download completes. No effect if no ongoing sync operation. Any delayed sync is cancelled.
    public func stopSync() {
        Synchronized.block(self) {
            if syncOperating {
                delayedSync = false
                stoppingSync = true
                SyncManager.session.stopSync = true
            }
        }
    }
    
    public struct Stats {
        public let downloadsAvailable:Int
        public let downloadDeletionsAvailable:Int
    }
    
    // completion gives nil if there was an error. This information is for general purpose use (e.g., UI) and makes no guarantees about files to be downloaded when you next do a `sync` operation.
    public func getStats(completion:@escaping (Stats?)->()) {
        Download.session.onlyCheck() { onlyCheckResult in
            switch onlyCheckResult {
            case .error(let error):
                Log.error("Error on Download onlyCheck: \(error)")
                completion(nil)
                
            case .checkResult(downloadFiles: let downloadFiles, downloadDeletions: let downloadDeletions, _):
                let stats = Stats(downloadsAvailable: downloadFiles?.count ?? 0, downloadDeletionsAvailable: downloadDeletions?.count ?? 0)
                completion(stats)
            }
        }
    }
    
     // This is powerful method. It permanently removes all local/cached metadata known by the client interface. E.g., metadata about files that you have previously uploaded. It makes no server calls. This is similar to deleting and re-installing the app-- except that it does not delete the files referenced by the meta data. You must keep track of files and, if desired, delete them. It also doesn't sign out the user or require that the user is signed in.
     // This method may only be called when the client is not doing any sync operations.
    public func reset() throws {
        var result:SyncServerError?
        
        Synchronized.block(self) {
            if syncOperating {
                result = .syncIsOperating
            }
            else {
                do {
                    try SyncServer.resetMetaData()
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
    internal static func resetMetaData() throws /* SyncServerError */ {
        var result:SyncServerError?

        CoreData.sessionNamed(Constants.coreDataName).performAndWait {
            DownloadFileTracker.removeAll()
            DirectoryEntry.removeAll()
            UploadFileTracker.removeAll()
            UploadQueue.removeAll()
            UploadQueues.removeAll()
            Singleton.removeAll()
            NetworkCached.removeAll()

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
    
    public struct LocalConsistencyResults {
        public let clientMissingAndDeleted:Set<UUIDString>!
        public let clientMissingNotDeleted:Set<UUIDString>!
        public let directoryMissing:Set<UUIDString>!
    }
    
    // Performs a similar operation to a file system consistency or integrity check. Only operates if not currently synchronizing. Suitable for running at app startup.
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
                
                CoreData.sessionNamed(Constants.coreDataName).performAndWait() {
                    do {
                        let directoryEntries = try CoreData.sessionNamed(Constants.coreDataName).fetchAllObjects(withEntityName: DirectoryEntry.entityName()) as? [DirectoryEntry]
                        if directoryEntries != nil {
                            for entry in directoryEntries! {
                                if !entry.deletedOnServer {
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
                CoreData.sessionNamed(Constants.coreDataName).performAndWait() {
                    for missing in clientMissing {
                        if let entry = DirectoryEntry.fetchObjectWithUUID(uuid: missing), !entry.deletedOnServer {
                            clientMissingNotDeleted.insert(missing)
                        }
                    }
                }
                
                let clientMissingAndDeleted = clientMissing.subtracting(clientMissingNotDeleted)
                
                // Elements in directory that are missing in client
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
    
    private func start(completion:(()->())?) {
        EventDesired.reportEvent(.syncStarted, mask: self.eventsDesired, delegate: self.delegate)
        Log.msg("SyncServer.start")
        
        SyncManager.session.start(first: true) { error in
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
                CoreData.sessionNamed(Constants.coreDataName).performAndWait() {
                    if !self.stoppingSync && (Upload.haveSyncQueue()  || self.delayedSync) {
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
                self.start(completion:completion)
            }
        }
    }

    private func resetFileTrackers() {
        CoreData.sessionNamed(Constants.coreDataName).performAndWait() {
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

            // Not sure how to report an error here...
            CoreData.sessionNamed(Constants.coreDataName).saveContext()
        }
    }

    // This is intended for development/debug only. This enables you do a consistency check between your local files and SyncServer meta data. Does a sync first to ensure files are synchronized.
    // TODO: *2* This is incomplete. Needs more work.
    public func consistencyCheck(localFiles:[UUIDString], repair:Bool = false, completion:((Error?)->())?) {
        sync {
            // TODO: *2* Check for errors in sync.
            Consistency.check(localFiles: localFiles, repair: repair, callback: completion)
        }
    }
}
