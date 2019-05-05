//
//  SyncController.swift
//  SharedImages
//
//  Created by Christopher Prince on 3/12/17.
//  Copyright © 2017 Spastic Muffin, LLC. All rights reserved.
//

import Foundation
import SyncServer
import SMCoreLib
import rosterdev
import SyncServer_Shared

enum SyncControllerEvent {
    case syncDelayed
    case syncStarted
    case syncDone(numberOperations: Int)
    case syncError(message: String)
    case syncServerDown
}

struct MediaData {
    let file: FileData
    let title:String?
    let creationDate: NSDate?
    let discussionUUID:String?
    let fileGroupUUID:String?
    let mediaType: MediaType.Type
}

struct FileData {
    // This will be nil when a file is `gone`.
    let url: SMRelativeLocalURL?
    
    let mimeType:MimeType
    
    // This will be non-nil when we have an assigned UUID being downloaded from the server.
    let fileUUID:String?
    
    let sharingGroupUUID:String
    
    // If file is gone, this is non-nil.
    let gone: GoneReason?
}

protocol SyncControllerDelegate : class {
    func userRemovedFromAlbum(syncController:SyncController, sharingGroup: SyncServer.SharingGroup)
    
    // Adding or updating media-- the update part is for errors that occurred on an original media download (read problem or "gone" errors).
    func addOrUpdateLocalMedia(syncController:SyncController, mediaData: MediaData, attr: SyncAttributes)
    
    // This will either be for a new discussion (corresponding to a new image or other media) or it will be additional data for an existing discussion (with an existing image or other media).
    func addToLocalDiscussion(syncController:SyncController, discussionData: FileData, attr: SyncAttributes)
    
    func addLocalAuxillaryFile(syncController:SyncController, fileData: FileData, attr: SyncAttributes, fileType: Files.FileType)
    
    func updateUploadedMediaDate(syncController:SyncController, uuid: String, creationDate: NSDate)
    func completedAddingOrUpdatingLocalMedia(syncController:SyncController)
    
    // fileType is optional ony because in early versions of the app, we didn't have fileType in the appMetaData on the server.
    func fileGoneDuringUpload(syncController:SyncController, uuid: String, fileType: Files.FileType?, reason: GoneReason)

    // Including removing any discussion thread.
    func removeLocalMedia(syncController:SyncController, uuid:String)
    
    // For handling deletion conflicts.
    func redoMediaUpload(syncController: SyncController, forDiscussion attr: SyncAttributes)
    
    func syncEvent(syncController:SyncController, event:SyncControllerEvent)
}

class SyncController {
    let minIntervalBetweenErrorReports: TimeInterval = 60
    private var syncDone:(()->())?
    private var lastReportedErrorTime: Date?
    let intervalBetweenPeriodicSyncs: TimeInterval = 60
    var timer: Timer?

    init() {
        SyncServer.session.delegate = self
        SyncServer.session.eventsDesired = [.syncDelayed, .syncStarted, .syncDone, .willStartDownloads, .willStartUploads,
                .singleFileUploadComplete, .singleFileUploadGone, .singleUploadDeletionComplete,
                .sharingGroupUploadOperationCompleted, .sharingGroupOwningUserRemoved,
                .serverDown, .minimumIOSClientVersion]

        startPeriodicSync()

        // 12/29/18; [1] So that when app goes into background/foreground, the periodic sync stops and starts. There is separate code in the AppDelegate, in performFetchWithCompletionHandler, that runs infrequently in the background to keep the app badge up to date.
//        NotificationCenter.default.addObserver(self, selector:#selector(stopPeriodicSync), name:
//            UIApplication.willResignActiveNotification, object: nil)
//        NotificationCenter.default.addObserver(self, selector:#selector(startPeriodicSync), name:
//            UIApplication.willEnterForegroundNotification, object: nil)
    }
    
    // Not called on app initial launch.
    func appWillEnterForeground() {
        startPeriodicSync()
    }
    
    func appDidEnterBackground() {
        stopPeriodicSync()
    }

    @objc private func startPeriodicSync() {
        Log.info("startPeriodicSync")
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: intervalBetweenPeriodicSyncs, repeats: true) { _ in
            if !SyncServer.session.isSyncing && SignInManager.session.userIsSignedIn {
                Log.info("startPeriodicSync: sync")
                do {
                    try SyncServer.session.sync()
                } catch (let error) {
                    Log.error("\(error)")
                }
            }
        }
    }

    @objc private func stopPeriodicSync() {
        timer?.invalidate()
        timer = nil
    }
    
    weak var delegate:SyncControllerDelegate!
    private var numberOperations = 0
    
    func sync(sharingGroupUUID: String, completion: (()->())? = nil) throws {
        syncDone = completion
        Log.info("About to do SyncController.sync sync")
        try SyncServer.session.sync(sharingGroupUUID: sharingGroupUUID)
    }
    
    // All objects are assumed to be in the same sharing group.
    func add(objects:[FileObject], errorCleanup: ()->()) {
        guard objects.count > 0 else {
            return
        }
        
        let sharingGroupUUID = objects[0].sharingGroupUUID!
        
        guard queueFileObjects(objects: objects) else {
            errorCleanup()
            return
        }
        
        var pnMessage: String
        if objects.count == 1 {
            pnMessage = "Added media."
        }
        else {
            pnMessage = "Added \(objects.count) media."
        }
        
        // Separate out the sync so that we can, later, dequeue syncs should we fail.
        do {
            try SyncServer.session.sync(sharingGroupUUID: sharingGroupUUID, pushNotificationMessage: pnMessage)
        } catch (let error) {
            errorCleanup()
            // Similar hack like the above.
            TimedCallback.withDuration(2.0) {
                SMCoreLib.Alert.show(withTitle: "Alert!", message: "An error occurred when trying to sync your media.")
            }
            Log.error("An error occurred: \(error)")
        }
    }

    private func queueFileObject(_ fileObject: FileObject) -> Bool {
        guard let rawMimeType = fileObject.mimeType,
            let mimeType = MimeType(rawValue: rawMimeType) else {
                SMCoreLib.Alert.show(withTitle: "Alert!", message: "Unknown mime type: \(fileObject.mimeType ?? "")")
            return false
        }
        
        guard let fileType = Files.FileType.from(object: fileObject) else {
            return false
        }
    
        // 12/27/17; Not sending dates to the server-- it establishes the dates.
        var syncAttr = SyncAttributes(fileUUID:fileObject.uuid!, sharingGroupUUID: fileObject.sharingGroupUUID!, mimeType:mimeType)
    
        syncAttr.fileGroupUUID = fileObject.fileGroupUUID
    
        var appMetaData = [String: Any]()
    
        // 4/17/18; Image titles, for new images, are stored in the "discussion" file.
        // imageAppMetaData[ImageExtras.appMetaDataTitleKey] = image.title
    
        // 5/13/18; Only storing file type in appMetaData for new files.
        // imageAppMetaData[ImageExtras.appMetaDataDiscussionUUIDKey] = discussion.uuid
    
        appMetaData[AppMetaDataKey.fileType.rawValue] = fileType.rawValue
        syncAttr.appMetaData = String.dictToJSONString(appMetaData)
        assert(syncAttr.appMetaData != nil)

        do {
            let uploadSyncType = fileType.uploadSyncType
            switch uploadSyncType {
            case .copy:
                try SyncServer.session.uploadCopy(localFile: fileObject.url!, withAttributes: syncAttr)
            case .immutable:
                try SyncServer.session.uploadImmutable(localFile: fileObject.url!, withAttributes: syncAttr)
            }
        } catch (let error) {
            // TODO: Need to dequeue the media enqueue if it was the discussion enqueue that failed. See https://github.com/crspybits/SyncServer-iOSClient/issues/62 I'm going to do this really crudely right now.
            try? SyncServer.session.reset(type: .tracking)
    
            // A hack because otherwise the VC we ned to show the alert is not present: Instead, the UI for image selection is still present.
            TimedCallback.withDuration(2.0) {
                SMCoreLib.Alert.show(withTitle: "Alert!", message: "An error occurred when trying to start the upload of your media.")
            }
    
            Log.error("An error occurred: \(error)")
            return false
        }
        
        return true
    }
    
    private func queueFileObjects(objects: [FileObject]) -> Bool {
        for object in objects {
            if !queueFileObject(object) {
                return false
            }
        }

        return true
    }
    
    func update(discussion: DiscussionFileObject) {
        guard let discussionMimeTypeEnum = MimeType(rawValue: discussion.mimeType!) else {
            SMCoreLib.Alert.show(withTitle: "Alert!", message: "Unknown discussion mime type: \(discussion.mimeType!)")
            return
        }
        
        let discussionAttr = SyncAttributes(fileUUID:discussion.uuid!, sharingGroupUUID: discussion.sharingGroupUUID!, mimeType:discussionMimeTypeEnum)
        
        do {
            // Like before, since discussions are mutable, use uploadCopy.
            try SyncServer.session.uploadCopy(localFile: discussion.url!, withAttributes: discussionAttr)
            
            try SyncServer.session.sync(sharingGroupUUID: discussion.sharingGroupUUID!, pushNotificationMessage: "Updated media discussion.")
        } catch (let error) {
            Log.error("An error occurred: \(error)")
        }
    }
    
    // Also removes associated discussions, on the server. The media must be in the same sharing group.
    func remove(media:[FileMediaObject], sharingGroupUUID: String) -> Bool {
        let mediaUuids = media.map({$0.uuid!})
        let mediaWithDiscussions = media.filter({$0.discussion != nil && $0.discussion!.uuid != nil})
        let discussionUuids = mediaWithDiscussions.map({$0.discussion!.uuid!})
        
        // 2017-11-27 02:51:29 +0000: An error occurred: fileAlreadyDeleted [remove(images:) in SyncController.swift, line 64]

        let message = "Removed \(media.count) media."
        
        do {
            try SyncServer.session.delete(filesWithUUIDs: mediaUuids + discussionUuids)
            try SyncServer.session.sync(sharingGroupUUID: sharingGroupUUID, pushNotificationMessage: message)
        } catch (let error) {
            Log.error("An error occurred: \(error)")
            return false
        }
        
        return true
    }
}

extension SyncController : SyncServerDelegate {
    func syncServerSharingGroupsDownloaded(created: [SyncServer.SharingGroup], updated: [SyncServer.SharingGroup], deleted: [SyncServer.SharingGroup]) {
        deleted.forEach { album in
            delegate.userRemovedFromAlbum(syncController: self, sharingGroup: album)
        }
    }
    
    func syncServerMustResolveContentDownloadConflict(_ downloadContent: ServerContentType, downloadedContentAttributes: SyncAttributes, uploadConflict: SyncServerConflict<ContentDownloadResolution>) {

        let errorResolution: ContentDownloadResolution = .acceptContentDownload
        
        switch uploadConflict.conflictType! {
        case .contentUpload(let conflictingUploadType):
            guard conflictingUploadType == .file else {
                // For now, the only use we're making of appMetaData is for storing file type information, and that's set only once-- when the files are created. So, should never have a conflict.
                Log.error("Conflict in appMetaData being uploaded!")
                uploadConflict.resolveConflict(resolution: errorResolution)
                return
            }
            
            switch downloadContent {
            case .both:
                // As above, this shouldn't happen.
                Log.error("Conflict in appMetaData being downloaded!")
                uploadConflict.resolveConflict(resolution: errorResolution)
                
            case .appMetaData:
                // As above, this shouldn't happen.
                Log.error("Conflict in appMetaData being downloaded!")
                uploadConflict.resolveConflict(resolution: errorResolution)
                
            case .file(let downloadedFile):
                // We have discussion content we're trying to upload, and someone else added discussion content. Don't use either our upload or the download directly. Instead merge the content, and make a new upload with the result.
                guard let discussion = DiscussionFileObject.fetchObjectWithUUID(downloadedContentAttributes.fileUUID),
                    let discussionURL = discussion.url as URL?,
                    let localDiscussion = FixedObjects(withFile: discussionURL),
                    let serverDiscussion = FixedObjects(withFile: downloadedFile as URL) else {
                    Log.error("Error! Yark! We had a conflict but had problems. Oh. My.")
                    uploadConflict.resolveConflict(resolution: errorResolution)
                    return
                }

                let (mergedDiscussion, unreadCount) = localDiscussion.merge(with: serverDiscussion)
                let attr = SyncAttributes(fileUUID: downloadedContentAttributes.fileUUID, sharingGroupUUID: discussion.sharingGroupUUID!, mimeType: downloadedContentAttributes.mimeType)
                
                // I'm going to use a new file, just in case we have an error writing.
                let mergeURL = Files.newJSONFile()
                
                do {
                    try mergedDiscussion.save(toFile: mergeURL as URL)
                    try FileManager.default.removeItem(at: discussionURL)
                    
                    discussion.url = mergeURL
                    discussion.unreadCount = Int32(unreadCount)
                    CoreData.sessionNamed(CoreDataExtras.sessionName).saveContext()

                    // As before, discussion are mutable-- upload a copy.
                    try SyncServer.session.uploadCopy(localFile: mergeURL, withAttributes: attr)
                    
                    try SyncServer.session.sync(sharingGroupUUID: discussion.sharingGroupUUID!)
                } catch (let error) {
                    Log.error("Problems writing merged discussion or uploading: \(error)")
                    uploadConflict.resolveConflict(resolution: errorResolution)
                    return
                }

                uploadConflict.resolveConflict(resolution: .rejectContentDownload(.removeAll))
            }
            
        // For now, we're going to prioritize the server operation. We've queued up a local deletion-- seems no loss if we accept the new download. We can always try the deletion again.
        case .uploadDeletion, .both:
            uploadConflict.resolveConflict(resolution: .acceptContentDownload)
        }
    }
    
    private func handleGroupDownload(group: [DownloadOperation]) {
        group.forEach { operation in
            switch operation.type {
            case .appMetaData:
                // We're using appMetaData only for file type info, which is established when a new image/discussion is uploaded. We shouldn't generally get appMetaData updates/downloads.
                Log.warning("appMetaData download!")
            case .deletion:
                // Conditioning this by media because deleting a media object deletes the associated discussion also.
                if Files.FileType.isMedia(attr: operation.attr) {
                    delegate.removeLocalMedia(syncController: self, uuid: operation.attr.fileUUID)
                }
                Progress.session.next(count: 1)

            case .file(let url, contentsChanged: let contentsChanged):
                // Just checking this, for debugging. It turns out this flag isn't very useful at least in SharedImages-- the real test for this app is whether or not the (a) media file or (b) discussion thread file can be read and parsed properly.
                Log.info("contentsChanged: \(contentsChanged)")
                
                singleFileDownloadComplete(.success(url: url, attr: operation.attr))
            
            case .fileGone:
                singleFileDownloadComplete(.gone(attr: operation.attr))
            }
        }
    }
    
    func syncServerFileGroupDownloadComplete(group: [DownloadOperation]) {
        handleGroupDownload(group: group)
    }
    
    func syncServerFileGroupDownloadGone(group: [DownloadOperation]) {
        handleGroupDownload(group: group)
    }
    
    enum FileDownloadComplete {
        case success(url:SMRelativeLocalURL, attr: SyncAttributes)
        case gone(attr: SyncAttributes)
    }
    
    // This is for original/first download of a file, and subsequent re-downloads/updates of the same file. Both of these cases can happen for both discussions and images.
    private func singleFileDownloadComplete(_ file: FileDownloadComplete) {
        var attr: SyncAttributes!
        
        switch file {
        case .gone(attr: let goneAttr):
            attr = goneAttr
        case .success(url: _, attr: let successAttr):
            attr = successAttr
        }
        
        let (fileTypeString, fileType) = Files.FileType.from(appMetaData: attr.appMetaData)
        
        if let fileTypeString = fileTypeString {
            guard let fileType = fileType else {
                Log.error("Unknown file type: \(fileTypeString)")
                return
            }
            
            switch fileType {
            case .discussion:
                discussionDownloadComplete(file)
            
            case .urlPreviewImage:
                auxillaryFileDownloadComplete(file, fileType: fileType)
                
            case .image, .url:
                mediaDownloadComplete(file, mediaType: fileType)
            }
            
            return
        }
        
        // We don't have type info in the appMetaData-- too early of a file version. Assume it's an image.
        mediaDownloadComplete(file, mediaType: .image)
    }
    
    // For a) first downloads and b) updates (error cases and new content) of the same auxillary file.
    private func auxillaryFileDownloadComplete(_ file: FileDownloadComplete, fileType: Files.FileType) {
        var attr: SyncAttributes!
        var url: SMRelativeLocalURL?
        
        switch file {
        case .gone(attr: let goneAttr):
            attr = goneAttr
        case .success(url: let successURL, attr: let successAttr):
            attr = successAttr

            let newFileURL = fileType.createNewURL()

            // The files we get back from the SyncServer are in a temporary location. We own them though so can move it.
            do {
                try FileManager.default.moveItem(at: successURL as URL, to: newFileURL as URL)
                url = newFileURL
            } catch (let error) {
                Log.error("An error occurred moving a file: \(error)")
            }
        }

        let auxFileData = FileData(url: url, mimeType: attr.mimeType, fileUUID: attr.fileUUID, sharingGroupUUID: attr.sharingGroupUUID, gone: attr.gone)
        delegate.addLocalAuxillaryFile(syncController: self, fileData: auxFileData, attr: attr, fileType: fileType)
        
        Progress.session.next()
    }
    
    // For a) first downloads and b) updates (error cases) of the same media file.
    private func mediaDownloadComplete(_ file: FileDownloadComplete, mediaType: Files.FileType) {
        var attr: SyncAttributes!
        var url: SMRelativeLocalURL?
        var type: MediaType.Type!

        type = mediaType.toFileObjectType() as? MediaType.Type
        guard type != nil else {
            assert(false)
            return
        }
        
        switch file {
        case .gone(attr: let goneAttr):
            attr = goneAttr
        case .success(url: let successURL, attr: let successAttr):
            attr = successAttr

            // The files we get back from the SyncServer are in a temporary location. We own them though, so can move them.
            let newURL = mediaType.createNewURL()
            
            do {
                try FileManager.default.moveItem(at: successURL as URL, to: newURL as URL)
                url = newURL
            } catch (let error) {
                Log.error("An error occurred moving a file: \(error)")
            }
        }

        var title:String?
        var discussionUUID:String?
        
        Log.info("attr.appMetaData: \(String(describing: attr.appMetaData))")
    
        // If present, the appMetaData will be a JSON string
        if let appMetaData = attr.appMetaData,
            let jsonDict = appMetaData.jsonStringToDict() {
            
            // Early files in the system won't give a title in the appMetaData, and later files won't either. Later files put the title into the "discussion" file.
            title = jsonDict[AppMetaDataKey.title.rawValue] as? String
            
            // Similarly, early files in the system won't have this. And later one's won't either-- discussion threads are connected to images in that case by the fileGroupUUID in the SyncAttributes.
            discussionUUID = jsonDict[AppMetaDataKey.discussionUUID.rawValue] as? String
        }

        let mediaFileData = FileData(url: url, mimeType: attr.mimeType, fileUUID: attr.fileUUID, sharingGroupUUID: attr.sharingGroupUUID, gone: attr.gone)
        let mediaData = MediaData(file: mediaFileData, title: title, creationDate: attr.creationDate as NSDate?, discussionUUID: discussionUUID, fileGroupUUID: attr.fileGroupUUID, mediaType: type)

        delegate.addOrUpdateLocalMedia(syncController: self, mediaData: mediaData, attr: attr)
        
        delegate.completedAddingOrUpdatingLocalMedia(syncController: self)
        Progress.session.next()
    }
    
    // For a) first downloads and b) updates (error cases and new image content) of the same discussion file.
    private func discussionDownloadComplete(_ file: FileDownloadComplete) {
        var attr: SyncAttributes!
        var url: SMRelativeLocalURL?
        
        switch file {
        case .gone(attr: let goneAttr):
            attr = goneAttr
        case .success(url: let successURL, attr: let successAttr):
            attr = successAttr
            
            // The files we get back from the SyncServer are in a temporary location. We own them though so can move it.
            let newJSONFileURL = Files.newJSONFile()
            do {
                try FileManager.default.moveItem(at: successURL as URL, to: newJSONFileURL as URL)
                url = newJSONFileURL
            } catch (let error) {
                Log.error("An error occurred moving a file: \(error)")
            }
        }

        let discussionFileData = FileData(url: url, mimeType: attr.mimeType, fileUUID: attr.fileUUID, sharingGroupUUID: attr.sharingGroupUUID, gone: attr.gone)
        delegate.addToLocalDiscussion(syncController: self, discussionData: discussionFileData, attr: attr)
        
        Progress.session.next()
    }
    
    // This has some some difficult technical problems. See https://github.com/crspybits/SharedImages/issues/77
    func syncServerMustResolveDownloadDeletionConflicts(conflicts:[DownloadDeletionConflict]) {
        conflicts.forEach() { (downloadDeletion: SyncAttributes, uploadConflict: SyncServerConflict<DownloadDeletionResolution>) in
            
            switch uploadConflict.conflictType {
            case .some(.contentUpload(.appMetaData)):
                // SyncServer doesn't allow keepContentUpload in this case.
                uploadConflict.resolveConflict(resolution: .acceptDownloadDeletion)
                
            default:
                // The content upload should be the discussion thread-- because SharedImages doesn't allow changes to images. We need to again enqueue the image for upload to get undeletion of that image on the server. Note that there is a tricky bit here in terms of groups. The image and the discussion are *not* going to be downloaded by clients together. Because doing sync here will enqueue the upload in a separate committed operation. I don't think this is going to be a problem for SharedImages, but not sure about other clients.
                // The image deletion will presumably also be in the set of deletions that will be carried out after this conflict is resolved -- but this `rejectDownloadDeletion` will reject *all* of the deletions in the group.
                uploadConflict.resolveConflict(resolution:
                    .rejectDownloadDeletion(.keepContentUpload))
                
                // I'm not sure if this is going to work embedded in the conflict resolution callback. I'm going to run it on the main thread to be safe.
                DispatchQueue.main.async {
                    self.delegate.redoMediaUpload(syncController: self, forDiscussion: downloadDeletion)
                }
            }
        }
    }
    
    func syncServerErrorOccurred(error:SyncServerError) {
        let syncServerError = "Server error occurred: \(error)"
        Log.error(syncServerError)
        turnIdleTimerOn()
        
        // Because these errors (a) result in UI prompts, and (b) we don't want too frequent of UI prompts, make sure there are not too many close together in time.
        let currErrorTime = Date()
        
        if let lastErrorTime = lastReportedErrorTime {
            let errorInterval = currErrorTime.timeIntervalSince(lastErrorTime)
            if errorInterval < minIntervalBetweenErrorReports {
                return
            }
        }
        
        lastReportedErrorTime = currErrorTime
        
        switch error {
        case .noCellularDataConnection:
            SMCoreLib.Alert.show(withTitle: "The network connection was lost!", message: "It seems there was no wifi and cellular data is turned off for this app.")
            return
            
        case .noNetworkError:
            SMCoreLib.Alert.show(withTitle: "The network connection was lost!", message: "Please try again later.")
            return
            
        case .badServerVersion(let actualServerVersion):
            let version = actualServerVersion == nil ? "nil" : actualServerVersion!.rawValue
            SMCoreLib.Alert.show(withTitle: "Bad server version", message: "actualServerVersion: \(version)")
            return
            
        default:
            break
        }
        
        if let delegate = delegate {
            delegate.syncEvent(syncController: self, event: .syncError(message: syncServerError))
        }
    }

#if DEBUG
    private func delayedCrash() {
        DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(1)) {
            let x:Int! = nil
            print("\(x!)")
        }
    }
#endif

    private func turnIdleTimerOff() {
        // 1/25/19; See https://github.com/crspybits/SharedImages/issues/157
        UIApplication.shared.isIdleTimerDisabled = true
        Log.info("Idle timer: Off")
    }
    
    private func turnIdleTimerOn() {
        // 1/25/19; See https://github.com/crspybits/SharedImages/issues/157
        UIApplication.shared.isIdleTimerDisabled = false
        Log.info("Idle timer: On")
    }

    func syncServerEventOccurred(event:SyncEvent) {
        Log.info("Server event occurred: \(event)")

        switch event {
        case .syncDelayed:
            delegate.syncEvent(syncController: self, event: .syncDelayed)

        case .syncStarted:
            // 1/25/19; Don't do this here-- because app periodically does a sync, and this causes the screen timeout to be perpetually disabled. Instead doing this when we start a batch of downloads-- i.e., in .willStartDownloads.
            // turnIdleTimerOff()
            
            numberOperations = 0
            delegate.syncEvent(syncController: self, event: .syncStarted)
            
        case .serverDown(message: let message):
            turnIdleTimerOn()
            delegate.syncEvent(syncController: self, event: .syncServerDown)
            SMCoreLib.Alert.show(withTitle: "The server is down for maintenance.", message: message)
            
        case .minimumIOSClientVersion(let minVersion):
            if userNeedsToUpdateAppVersion(minVersion) {
                turnIdleTimerOn()
                
                var message: String
                #if DEBUG
                    message = "Please update it using TestFlight"
                #else
                    message = "Please update it using the App Store"
                #endif
                
                SMCoreLib.Alert.show(withTitle: "The Neebla app needs to be updated.", message: message, okCompletion: {[unowned self] in
                    #if DEBUG
                        self.openTestFlight()
                    #else
                        self.openAppStore(forAppIdentifier: "1244482164")
                    #endif
                })
            }

        case .willStartDownloads(numberContentDownloads: let numberContentDownloads, numberDownloadDeletions: let numberDownloadDeletions):
            turnIdleTimerOff()
            
            numberOperations += Int(numberContentDownloads + numberDownloadDeletions)
            
            RosterDevInjectTest.if(TestCases.session.testCrashNextDownload) {[unowned self] in
#if DEBUG
                self.delayedCrash()
#endif
            }
            
            Progress.session.start(withTotalNumber: Int(numberContentDownloads + numberDownloadDeletions))
            
            // TESTING
            // TimedCallback.withDuration(30, andCallback: {
            //     Network.session().debugNetworkOff = true
            // })
            // TESTING

        case .willStartUploads(numberContentUploads: let numberContentUploads, numberUploadDeletions: let numberUploadDeletions, numberSharingGroupOperatioms: _):
        
            numberOperations += Int(numberContentUploads + numberUploadDeletions)

            RosterDevInjectTest.if(TestCases.session.testCrashNextUpload) {[unowned self] in
#if DEBUG
                self.delayedCrash()
#endif
            }

            // Don't display progress indicator if we're only doing sharing group operations. No point-- these operations are relatively quick.
            if numberOperations > 0 {
                Progress.session.start(withTotalNumber: numberOperations)
            }
            
        case .singleFileUploadComplete(attr: let attr):
            let (_, fileType) = Files.FileType.from(appMetaData: attr.appMetaData)
            if fileType == nil || fileType == .image {
                // Include the nil case because files without types are images-- i.e., they were created before we started typing files in the meta data.
                Log.info("fileType: \(String(describing: fileType))")
                delegate.updateUploadedMediaDate(syncController: self, uuid: attr.fileUUID, creationDate: attr.creationDate! as NSDate)
            }
            
            Progress.session.next()
            
        case .singleFileUploadGone(attr: let attr):
            let (_, fileType) = Files.FileType.from(appMetaData: attr.appMetaData)
            delegate.fileGoneDuringUpload(syncController: self, uuid: attr.fileUUID, fileType: fileType, reason: attr.gone!)
            Progress.session.next()
            
        case .singleUploadDeletionComplete:
            Progress.session.next()

        case .sharingGroupUploadOperationCompleted(sharingGroup: let sharingGroup, operation: let operation):
            switch operation {
            case .userRemoval:
                delegate.userRemovedFromAlbum(syncController: self, sharingGroup: sharingGroup)
            case .creation, .update:
                break
            }
            
        case .sharingGroupOwningUserRemoved(let sharingGroup):
            var albumName = "an unnamed album"
            if let name = sharingGroup.sharingGroupName {
                albumName = "the album named \(name)"
            }
            
            SMCoreLib.Alert.show(withTitle: "Your inviting user was removed from \(albumName).", message: "You will no longer be able to upload new images to this album.")
            
        case .syncDone:
            turnIdleTimerOn()
            
            // 8/12/17; https://github.com/crspybits/SharedImages/issues/13
            let syncNeeded = SyncServer.session.sharingGroups.filter {$0.syncNeeded!}
            AppBadge.setBadge(number: syncNeeded.count)
            
            delegate.syncEvent(syncController: self, event: .syncDone(numberOperations: numberOperations))
            syncDone?()
            syncDone = nil
            Progress.session.finish()
        
        default:
            Log.error("Unexpected event received: \(event)")
            break
        }
    }
    
    private func userNeedsToUpdateAppVersion(_ minVersion:ServerVersion) -> Bool {
        guard let currentAppVersionString = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
            let currentAppVersion = ServerVersion(rawValue: currentAppVersionString) else {
            Log.error("Could not get current iOS app version version from bundle")
            return false
        }
        
        return currentAppVersion < minVersion
    }
    
    private func openAppStore(forAppIdentifier identifier: String) {
         // App Store URL.
         let appStoreLink = "https://itunes.apple.com/us/app/apple-store/id\(identifier)?mt=8"
        
         /* First create a URL, then check whether there is an installed app that can
            open it on the device. */
        if let url = URL(string: appStoreLink), UIApplication.shared.canOpenURL(url) {
           // Attempt to open the URL.
           UIApplication.shared.open(url, options: [:], completionHandler: nil)
        }
    }
    
    private func openTestFlight() {
        if let customAppURL = URL(string: "itms-beta://") {
            if UIApplication.shared.canOpenURL(customAppURL) {
                UIApplication.shared.open(customAppURL, options: [:], completionHandler: nil)
            }
        }
    }
}
