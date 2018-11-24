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
}

struct ImageData {
    let file: FileData
    let title:String?
    let creationDate: NSDate?
    let discussionUUID:String?
    let fileGroupUUID:String?
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
    
    // Adding or updating a image-- the update part is for errors that occurred on an original image download (read problem or "gone" errors).
    func addOrUpdateLocalImage(syncController:SyncController, imageData: ImageData, attr: SyncAttributes)
    
    // This will either be for a new discussion (corresponding to a new image) or it will be additional data for an existing discussion (with an existing image).
    func addToLocalDiscussion(syncController:SyncController, discussionData: FileData, attr: SyncAttributes)
    
    func updateUploadedImageDate(syncController:SyncController, uuid: String, creationDate: NSDate)
    func completedAddingOrUpdatingLocalImages(syncController:SyncController)
    
    // fileType is optional ony because in early versions of the app, we didn't have fileType in the appMetaData on the server.
    func fileGoneDuringUpload(syncController:SyncController, uuid: String, fileType: ImageExtras.FileType?, reason: GoneReason)

    // Including removing any discussion thread.
    func removeLocalImages(syncController:SyncController, uuids:[String])
    
    // For handling deletion conflicts.
    func redoImageUpload(syncController: SyncController, forDiscussion attr: SyncAttributes)
    
    func syncEvent(syncController:SyncController, event:SyncControllerEvent)
}

class SyncController {
    let minIntervalBetweenErrorReports: TimeInterval = 60
    private var syncDone:(()->())?
    private var lastReportedErrorTime: Date?
    
    init() {
        SyncServer.session.delegate = self
        SyncServer.session.eventsDesired = [.syncDelayed, .syncStarted, .syncDone, .willStartDownloads, .willStartUploads,
                .singleFileUploadComplete, .singleFileUploadGone, .singleUploadDeletionComplete,
                .sharingGroupUploadOperationCompleted, .sharingGroupOwningUserRemoved]
    }
    
    weak var delegate:SyncControllerDelegate!
    private var numberOperations = 0
    
    func sync(sharingGroupUUID: String, completion: (()->())? = nil) throws {
        syncDone = completion
        try SyncServer.session.sync(sharingGroupUUID: sharingGroupUUID)
    }
    
    private func dictToJSONString(_ dict: [String: Any]) -> String? {
        guard let data = try? JSONSerialization.data(withJSONObject: dict, options: JSONSerialization.WritingOptions(rawValue: 0)) else {
            return nil
        }
        
        guard let jsonString = String(data: data, encoding: String.Encoding.utf8) else {
            return nil
        }
        
        return jsonString
    }
    
    private func jsonStringToDict(_ jsonString: String) -> [String: Any]? {
        if let jsonData = jsonString.data(using: String.Encoding.utf8, allowLossyConversion: false) {
        
            if let json = try? JSONSerialization.jsonObject(with: jsonData, options: []) as? [String: Any] {
                return json
            }
        }
        
        return nil
    }
    
    // Add new image and discussion
    func add(image:Image, discussion: Discussion) {
        guard let imageMimeTypeEnum = MimeType(rawValue: image.mimeType!) else {
            SMCoreLib.Alert.show(withTitle: "Alert!", message: "Unknown image mime type: \(image.mimeType!)")
            return
        }
        
        guard let discussionMimeTypeEnum = MimeType(rawValue: discussion.mimeType!) else {
            SMCoreLib.Alert.show(withTitle: "Alert!", message: "Unknown discussion mime type: \(discussion.mimeType!)")
            return
        }
        
        // 12/27/17; Not sending dates to the server-- it establishes the dates.
        var imageAttr = SyncAttributes(fileUUID:image.uuid!, sharingGroupUUID: image.sharingGroupUUID!, mimeType:imageMimeTypeEnum)
        
        imageAttr.fileGroupUUID = image.fileGroupUUID
        
        var imageAppMetaData = [String: Any]()
        
        // 4/17/18; Image titles, for new images, are stored in the "discussion" file.
        // imageAppMetaData[ImageExtras.appMetaDataTitleKey] = image.title
        
        // 5/13/18; Only storing file type in appMetaData for new files.
        // imageAppMetaData[ImageExtras.appMetaDataDiscussionUUIDKey] = discussion.uuid
        
        imageAppMetaData[ImageExtras.appMetaDataFileTypeKey] = ImageExtras.FileType.image.rawValue

        imageAttr.appMetaData = dictToJSONString(imageAppMetaData)
        assert(imageAttr.appMetaData != nil)
        
        var discussionAttr = SyncAttributes(fileUUID:discussion.uuid!, sharingGroupUUID: image.sharingGroupUUID!, mimeType:discussionMimeTypeEnum)
        discussionAttr.fileGroupUUID = discussion.fileGroupUUID
        
        var discussionAppMetaData = [String: Any]()
        discussionAppMetaData[ImageExtras.appMetaDataFileTypeKey] = ImageExtras.FileType.discussion.rawValue
        discussionAttr.appMetaData = dictToJSONString(discussionAppMetaData)
        assert(discussionAttr.appMetaData != nil)

        do {
            // Make sure to enqueue both the image and discussion for upload without an intervening sync -- they are in the same file group, and this will enable other clients to download them together.
            
            try SyncServer.session.uploadImmutable(localFile: image.url!, withAttributes: imageAttr)
            
            // Using uploadCopy for discussions in case the discussion gets updated locally before we complete this sync operation. i.e., discussions are mutable.
            try SyncServer.session.uploadCopy(localFile: discussion.url!, withAttributes: discussionAttr)
        } catch (let error) {
            // Also removes the discussion.
            try? image.remove()
            image.save()
            
            // TODO: Need to dequeue the image enqueue if it was the discussion enqueue that failed. See https://github.com/crspybits/SyncServer-iOSClient/issues/62 I'm going to do this really crudely right now.
            try? SyncServer.session.reset(type: .tracking)
            
            // A hack because otherwise the VC we ned to show the alert is not present: Instead, the UI for image selection is still present.
            TimedCallback.withDuration(2.0) {
                SMCoreLib.Alert.show(withTitle: "Alert!", message: "An error occurred when trying to start the upload of your image.")
            }
            
            Log.error("An error occurred: \(error)")
            return
        }
        
        // Separate out the sync so that we can, later, dequeue both syncs should we fail.
        do {
            try SyncServer.session.sync(sharingGroupUUID: image.sharingGroupUUID!)
        } catch (let error) {
            // Similar hack like the above.
            TimedCallback.withDuration(2.0) {
                SMCoreLib.Alert.show(withTitle: "Alert!", message: "An error occurred when trying to sync your image.")
            }
            Log.error("An error occurred: \(error)")
        }
    }
    
    func update(discussion: Discussion) {
        guard let discussionMimeTypeEnum = MimeType(rawValue: discussion.mimeType!) else {
            SMCoreLib.Alert.show(withTitle: "Alert!", message: "Unknown discussion mime type: \(discussion.mimeType!)")
            return
        }
        
        let discussionAttr = SyncAttributes(fileUUID:discussion.uuid!, sharingGroupUUID: discussion.sharingGroupUUID!, mimeType:discussionMimeTypeEnum)
        
        do {
            // Like before, since discussions are mutable, use uploadCopy.
            try SyncServer.session.uploadCopy(localFile: discussion.url!, withAttributes: discussionAttr)
            
            try SyncServer.session.sync(sharingGroupUUID: discussion.sharingGroupUUID!)
        } catch (let error) {
            Log.error("An error occurred: \(error)")
        }
    }
    
    // Also removes associated discussions, on the server. The images must be in the same sharing group.
    func remove(images:[Image], sharingGroupUUID: String) -> Bool {
        let imageUuids = images.map({$0.uuid!})
        let imagesWithDiscussions = images.filter({$0.discussion != nil && $0.discussion!.uuid != nil})
        let discussionUuids = imagesWithDiscussions.map({$0.discussion!.uuid!})
        
        // 2017-11-27 02:51:29 +0000: An error occurred: fileAlreadyDeleted [remove(images:) in SyncController.swift, line 64]
        do {
            try SyncServer.session.delete(filesWithUUIDs: imageUuids + discussionUuids)
            try SyncServer.session.sync(sharingGroupUUID: sharingGroupUUID)
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
                guard let discussion = Discussion.fetchObjectWithUUID(downloadedContentAttributes.fileUUID),
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
                let mergeURL = ImageExtras.newJSONFile()
                
                do {
                    try mergedDiscussion.save(toFile: mergeURL as URL)
                    try FileManager.default.removeItem(at: discussionURL)
                    
                    discussion.url = mergeURL
                    discussion.unreadCount = Int32(unreadCount)
                    CoreData.sessionNamed(CoreDataExtras.sessionName).saveContext()
                    UnreadCountBadge.update()

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
                // Conditioning this by image because deleting an image deletes the associated discussion also.
                if isImage(attr: operation.attr) {
                    delegate.removeLocalImages(syncController: self, uuids: [operation.attr.fileUUID])
                }
                Progress.session.next(count: 1)

            case .file(let url, contentsChanged: let contentsChanged):
                // Just checking this, for debugging. It turns out this flag isn't very useful at least in SharedImages-- the real test for this app is whether or not the (a) image file or (b) discussion thread file can be read and parsed properly.
                Log.msg("contentsChanged: \(contentsChanged)")
                
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
    
    func fileTypeFrom(appMetaData:String?) -> (fileTypeString: String?, ImageExtras.FileType?) {
        if let appMetaData = appMetaData,
            let jsonDict = jsonStringToDict(appMetaData),
            let fileTypeString = jsonDict[ImageExtras.appMetaDataFileTypeKey] as? String {
            
            if let fileType = ImageExtras.FileType(rawValue: fileTypeString) {
                return (fileTypeString, fileType)
            }
            
            return (fileTypeString, nil)
        }
        
        return (nil, nil)
    }
    
    func isImage(attr: SyncAttributes) -> Bool {
        let (fileTypeString, fileType) = fileTypeFrom(appMetaData: attr.appMetaData)
        if let fileTypeString = fileTypeString {
            guard let fileType = fileType else {
                Log.error("Unknown file type: \(fileTypeString)")
                return false
            }
            
            switch fileType {
            case .discussion:
                return false
                
            case .image:
                break
            }
        }
        
        return true
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
        
        let (fileTypeString, fileType) = fileTypeFrom(appMetaData: attr.appMetaData)
        
        if let fileTypeString = fileTypeString {
            guard let fileType = fileType else {
                Log.error("Unknown file type: \(fileTypeString)")
                return
            }
            
            switch fileType {
            case .discussion:
                discussionDownloadComplete(file)
                
            case .image:
                imageDownloadComplete(file)
            }
            
            return
        }
        
        // We don't have type info in the appMetaData-- too early of a file version. Assume it's an image.
        imageDownloadComplete(file)
    }
    
    // For a) first downloads and b) updates (error cases) of the same image file.
    private func imageDownloadComplete(_ file: FileDownloadComplete) {
        var attr: SyncAttributes!
        var url: SMRelativeLocalURL?
        
        switch file {
        case .gone(attr: let goneAttr):
            attr = goneAttr
        case .success(url: let successURL, attr: let successAttr):
            attr = successAttr

            // The files we get back from the SyncServer are in a temporary location. We own them though, so can move them.
            let newImageURL = FileExtras().newURLForImage()
            do {
                try FileManager.default.moveItem(at: successURL as URL, to: newImageURL as URL)
                url = newImageURL
            } catch (let error) {
                Log.error("An error occurred moving a file: \(error)")
            }
        }

        var title:String?
        var discussionUUID:String?
        
        Log.msg("attr.appMetaData: \(String(describing: attr.appMetaData))")
    
        // If present, the appMetaData will be a JSON string
        if let appMetaData = attr.appMetaData,
            let jsonDict = jsonStringToDict(appMetaData) {
            
            // Early files in the system won't give a title in the appMetaData, and later files won't either. Later files put the title into the "discussion" file.
            title = jsonDict[ImageExtras.appMetaDataTitleKey] as? String
            
            // Similarly, early files in the system won't have this. And later one's won't either-- discussion threads are connected to images in that case by the fileGroupUUID in the SyncAttributes.
            discussionUUID = jsonDict[ImageExtras.appMetaDataDiscussionUUIDKey] as? String
        }

        let imageFileData = FileData(url: url, mimeType: attr.mimeType, fileUUID: attr.fileUUID, sharingGroupUUID: attr.sharingGroupUUID, gone: attr.gone)
        let imageData = ImageData(file: imageFileData, title: title, creationDate: attr.creationDate as NSDate?, discussionUUID: discussionUUID, fileGroupUUID: attr.fileGroupUUID)

        delegate.addOrUpdateLocalImage(syncController: self, imageData: imageData, attr: attr)
        
        delegate.completedAddingOrUpdatingLocalImages(syncController: self)
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
            let newJSONFileURL = ImageExtras.newJSONFile()
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
                    self.delegate.redoImageUpload(syncController: self, forDiscussion: downloadDeletion)
                }
            }
        }
    }
    
    func syncServerErrorOccurred(error:SyncServerError) {
        let syncServerError = "Server error occurred: \(error)"
        Log.error(syncServerError)
        
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

    func syncServerEventOccurred(event:SyncEvent) {
        Log.msg("Server event occurred: \(event)")

        switch event {
        case .syncDelayed:
            delegate.syncEvent(syncController: self, event: .syncDelayed)

        case .syncStarted:
            numberOperations = 0
            delegate.syncEvent(syncController: self, event: .syncStarted)
            
        case .willStartDownloads(numberContentDownloads: let numberContentDownloads, numberDownloadDeletions: let numberDownloadDeletions):
            
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
        
            Progress.session.start(withTotalNumber: Int(numberContentUploads + numberUploadDeletions))
            
        case .singleFileUploadComplete(attr: let attr):
            let (_, fileType) = fileTypeFrom(appMetaData: attr.appMetaData)
            if fileType == nil || fileType == .image {
                // Include the nil case because files without types are images-- i.e., they were created before we started typing files in the meta data.
                Log.msg("fileType: \(String(describing: fileType))")
                delegate.updateUploadedImageDate(syncController: self, uuid: attr.fileUUID, creationDate: attr.creationDate! as NSDate)
            }
            
            Progress.session.next()
            
        case .singleFileUploadGone(attr: let attr):
            let (_, fileType) = fileTypeFrom(appMetaData: attr.appMetaData)
            delegate.fileGoneDuringUpload(syncController: self, uuid: attr.fileUUID, fileType: fileType, reason: attr.gone!)
            Progress.session.next()
            
        case .singleUploadDeletionComplete:
            // Because it is possible to delete an image for which you've not yet read messages, and the badge won't be updated.
            UnreadCountBadge.update()
            
            Progress.session.next()

        case .sharingGroupUploadOperationCompleted(sharingGroup: let sharingGroup, operation: let operation):
            switch operation {
            case .userRemoval:
                // Because it is possible to remove yourself from an album which you've not yet read messages, and the badge won't be updated.
                UnreadCountBadge.update()
                
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
            delegate.syncEvent(syncController: self, event: .syncDone(numberOperations: numberOperations))
            syncDone?()
            syncDone = nil
            Progress.session.finish()
        
        default:
            Log.error("Unexpected event received: \(event)")
            break
        }
    }
}
