//
//  SyncServer.swift
//  SyncServer
//
//  Created by Christopher Prince on 2/23/17.
//
//

import Foundation
import SMCoreLib

// Most of this information is for testing purposes and for UI (e.g., for displaying download progress). Some of it, however, can be necessary for app operations.
public enum SyncEvent {
    // This can repeat if there is a change to the files on the server (a master version update), and downloads restart.
    case willStartDownloads(numberFileDownloads:UInt, numberDownloadDeletions:UInt)
    
    case willStartUploads(numberFileUploads:UInt, numberUploadDeletions:UInt)
    
    // The attributes report the actual creation and update dates of the file-- as established by the server.
    case singleFileUploadComplete(attr:SyncAttributes)
    
    case singleUploadDeletionComplete(fileUUID:UUIDString)
    case fileUploadsCompleted(numberOfFiles:Int)
    case uploadDeletionsCompleted(numberOfFiles:Int)
    
    case syncStarted
    
    // Occurs after call to stopSync, when the synchronization is just about to stop. syncDone will be the next event (if desired).
    case syncStopping
    
    case syncDone
    
    case refreshingCredentials
}

public struct EventDesired: OptionSet {
    public let rawValue: Int
    public init(rawValue:Int){ self.rawValue = rawValue}

    public static let willStartDownloads = EventDesired(rawValue: 1 << 0)
    public static let willStartUploads = EventDesired(rawValue: 1 << 1)

    public static let singleFileUploadComplete = EventDesired(rawValue: 1 << 2)
    public static let singleUploadDeletionComplete = EventDesired(rawValue: 1 << 3)
    public static let fileUploadsCompleted = EventDesired(rawValue: 1 << 4)
    public static let uploadDeletionsCompleted = EventDesired(rawValue: 1 << 5)
    
    public static let syncStarted = EventDesired(rawValue: 1 << 6)
    public static let syncDone = EventDesired(rawValue: 1 << 7)
    
    public static let syncStopping = EventDesired(rawValue: 1 << 8)

    public static let refreshingCredentials = EventDesired(rawValue: 1 << 9)

    public static let defaults:EventDesired =
        [.singleFileUploadComplete, .singleUploadDeletionComplete, .fileUploadsCompleted,
         .uploadDeletionsCompleted]
    public static let all:EventDesired = EventDesired.defaults.union([EventDesired.syncStarted, EventDesired.syncDone, EventDesired.syncStopping, EventDesired.refreshingCredentials, EventDesired.willStartDownloads, EventDesired.willStartUploads])
    
    static func reportEvent(_ event:SyncEvent, mask:EventDesired, delegate:SyncServerDelegate?) {
    
        var eventIsDesired:EventDesired
        
        switch event {
        case .willStartDownloads:
            eventIsDesired = .willStartDownloads
            
        case .willStartUploads:
            eventIsDesired = .willStartUploads
            
        case .fileUploadsCompleted:
            eventIsDesired = .fileUploadsCompleted
            
        case .uploadDeletionsCompleted:
            eventIsDesired = .uploadDeletionsCompleted
        
        case .syncStarted:
            eventIsDesired = .syncStarted
            
        case .syncDone:
            eventIsDesired = .syncDone
            
        case .syncStopping:
            eventIsDesired = .syncStopping
            
        case .singleFileUploadComplete:
            eventIsDesired = .singleFileUploadComplete
            
        case .singleUploadDeletionComplete:
            eventIsDesired = .singleUploadDeletionComplete
        
        case .refreshingCredentials:
            eventIsDesired = .refreshingCredentials
        }
        
        if mask.contains(eventIsDesired) {
            Thread.runSync(onMainThread: {
                delegate?.syncServerEventOccurred(event: event)
            })
        }
    }
}

// Many of these only have internal meaning to the client. Some are documented because they can be useful to the code using the client.
public enum SyncServerError: Error {
    // The network connection was lost.
    case noNetworkError
    
    case syncIsOperating
    case alreadyDownloadingAFile
    case alreadyUploadingAFile
    case couldNotFindFileUUID(String)
    case versionForFileWasNil(fileUUUID: String)
    case noRefreshAvailable
    case couldNotCreateResponse
    case couldNotCreateRequest
    case didNotGetDownloadURL
    case couldNotMoveDownloadFile
    case couldNotReadUploadFile
    case couldNotCreateNewFileForDownload
    case obtainedAppMetaDataButWasNotString
    case noExpectedResultKey
    case nilResponse
    case couldNotObtainHeaderParameters
    case resultURLObtainedWasNil
    case errorConvertingServerResponse
    case jsonSerializationError(Error)
    case urlSessionError(Error)
    case couldNotGetHTTPURLResponse
    case non200StatusCode(Int)
    case badCheckCreds
    case unknownServerError
    case coreDataError(Error)
    case generic(String)
    
#if TEST_REFRESH_FAILURE
    case testRefreshFailure
#endif

    case credentialsRefreshError
}

// These delegate methods are called on the main thread.

public protocol SyncServerDelegate : class {
    /* Called at the end of a single download, on non-error conditions.
    The client owns the file referenced by the url after this call completes. This file is temporary in the sense that it will not be backed up to iCloud, could be removed when the device or app is restarted, and should be moved to a more permanent location.
    Client should replace their existing data with that from the given file.
    */
    func singleFileDownloadComplete(url:SMRelativeLocalURL, attr: SyncAttributes)

    // Called when deletions have been received from the server. I.e., these files have been deleted on the server. This is received/called in an atomic manner: This reflects a snapshot state of file deletions on the server. Clients should delete the files referenced by the SMSyncAttributes's (i.e., the UUID's).
    // This may be called sometime after the deletions have been received from the server. E.g., on a recovery step after the app launches and not after recent server interaction.
    func shouldDoDeletions(downloadDeletions:[SyncAttributes])
    
    func syncServerErrorOccurred(error:SyncServerError)

    // Reports events. Useful for testing and UI.
    func syncServerEventOccurred(event:SyncEvent)
}

#if DEBUG
public protocol SyncServerTestingDelegate : class {
    // You *must* call `next` before returning.
    func syncServerSingleFileUploadCompleted(next: @escaping ()->())
    
     // You *must* call `next` before returning. If this delegate is given in testing, then `SyncServerDelegate` is not used for the corresponding method (without `next`).
     func singleFileDownloadComplete(url:SMRelativeLocalURL, attr: SyncAttributes, next: @escaping ()->())
}
#endif

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
        
        Upload.session.cloudFolderName = cloudFolderName
        Network.session().appStartup()
        ServerAPI.session.baseURL = serverURL.absoluteString

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
        
        // SyncServerUser sets up the delegate for the ServerAPI. Need to set it up early in the launch sequence.
        SyncServerUser.session.appLaunchSetup()
    }
    
    public enum SyncClientAPIError: Error {
    case mimeTypeOfFileChanged
    case fileAlreadyDeleted
    case fileQueuedForDeletion
    case deletingUnknownFile
    }
    
    // Enqueue a local immutable file for subsequent upload. Immutable files are assumed to not change (at least until after the upload has completed). This immutable characteristic is not enforced by this class but needs to be enforced by the caller of this class.
    // This operation survives app launches, as long as the the call itself completes. 
    // If there is a file with the same uuid, which has been enqueued for upload but not yet `sync`'ed, it will be replaced by the given file. 
    // This operation does not access the server, and thus runs quickly and synchronously.
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
                if entry!.fileVersion != nil {
                    // Right now, we're not allowing uploads of multiple version files, so this is not allowed.
                    assert(false)
                }
                
                if attr.mimeType != entry!.mimeType {
                    errorToThrow = SyncClientAPIError.mimeTypeOfFileChanged
                    return
                }
                
                if entry!.deletedOnServer {
                    errorToThrow = SyncClientAPIError.fileAlreadyDeleted
                    return
                }
            }
            
            let newUft = UploadFileTracker.newObject() as! UploadFileTracker
            newUft.localURL = fileURL
            newUft.appMetaData = attr.appMetaData
            newUft.fileUUID = attr.fileUUID
            newUft.mimeType = attr.mimeType
            
            // TODO: *1* I think this mechanism for setting the file version of the UploadFileTracker is not correct. Analogous to the deletion case, where we wait until the last moment prior to the upload deletion, I think we have to wait until the last moment of file upload to figure out the file version of the upload. The issue comes in with a series of upload/sync/upload/sync's, where we won't get all of the file version's correct.
            if entry!.fileVersion == nil {
                newUft.fileVersion = 0
            }
            else {
                newUft.fileVersion = entry!.fileVersion! + 1
            }
            
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
            throw SyncClientAPIError.deletingUnknownFile
        }

        guard !entry.deletedOnServer else {
            throw SyncClientAPIError.fileAlreadyDeleted
        }

        // Check to see if there is a pending upload deletion with this UUID.
        let pendingUploadDeletions = UploadFileTracker.fetchAll().filter {$0.fileUUID == uuid && $0.deleteOnServer }
        if pendingUploadDeletions.count > 0 {
            throw SyncClientAPIError.fileQueuedForDeletion
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
            _ = dfts.map { dft in
                if dft.status == .downloading {
                    dft.status = .notStarted
                }
            }
            
            // Not sure how to report an error here...
            _ = try? Upload.pendingSync().uploadFileTrackers.map { uft in
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
