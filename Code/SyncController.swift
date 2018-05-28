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
    let url: SMRelativeLocalURL
    let mimeType:MimeType
    
    // This will be non-nil when we have an assigned UUID being downloaded from the server.
    let uuid:String?
}

protocol SyncControllerDelegate : class {
    // Adding a new image-- since images are immutable, this always results from downloading a new image.
    func addLocalImage(syncController:SyncController, imageData: ImageData, attr: SyncAttributes)
    
    // This will either be for a new discussion (corresponding to a new image) or it will be additional data for an existing discussion (with an existing image).
    func addToLocalDiscussion(syncController:SyncController, discussionData: FileData, attr: SyncAttributes)
    
    func updateUploadedImageDate(syncController:SyncController, uuid: String, creationDate: NSDate)
    func completedAddingLocalImages(syncController:SyncController)
    
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
        SyncServer.session.eventsDesired = [.syncStarted, .syncDone, .willStartDownloads, .willStartUploads,
                .singleFileUploadComplete, .singleUploadDeletionComplete]
    }
    
    weak var delegate:SyncControllerDelegate!
    private var numberOperations = 0
    
    func sync(completion: (()->())? = nil) {
        syncDone = completion
        SyncServer.session.sync()
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
        var imageAttr = SyncAttributes(fileUUID:image.uuid!, mimeType:imageMimeTypeEnum)
        
        imageAttr.fileGroupUUID = image.fileGroupUUID
        
        var imageAppMetaData = [String: Any]()
        
        // 4/17/18; Image titles, for new images, are stored in the "discussion" file.
        // imageAppMetaData[ImageExtras.appMetaDataTitleKey] = image.title
        
        // 5/13/18; Only storing file type in appMetaData for new files.
        // imageAppMetaData[ImageExtras.appMetaDataDiscussionUUIDKey] = discussion.uuid
        
        imageAppMetaData[ImageExtras.appMetaDataFileTypeKey] = ImageExtras.FileType.image.rawValue

        imageAttr.appMetaData = dictToJSONString(imageAppMetaData)
        assert(imageAttr.appMetaData != nil)
        
        var discussionAttr = SyncAttributes(fileUUID:discussion.uuid!, mimeType:discussionMimeTypeEnum)
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

            SyncServer.session.sync()
        } catch (let error) {
            Log.error("An error occurred: \(error)")
        }
    }
    
    func update(discussion: Discussion) {
        guard let discussionMimeTypeEnum = MimeType(rawValue: discussion.mimeType!) else {
            SMCoreLib.Alert.show(withTitle: "Alert!", message: "Unknown discussion mime type: \(discussion.mimeType!)")
            return
        }
        
        let discussionAttr = SyncAttributes(fileUUID:discussion.uuid!, mimeType:discussionMimeTypeEnum)
        
        do {
            // Like before, since discussions are mutable, use uploadCopy.
            try SyncServer.session.uploadCopy(localFile: discussion.url!, withAttributes: discussionAttr)
            SyncServer.session.sync()
        } catch (let error) {
            Log.error("An error occurred: \(error)")
        }
    }
    
    // Also removes associated discussions, on the server.
    func remove(images:[Image]) -> Bool {        
        let imageUuids = images.map({$0.uuid!})
        let imagesWithDiscussions = images.filter({$0.discussion != nil && $0.discussion!.uuid != nil})
        let discussionUuids = imagesWithDiscussions.map({$0.discussion!.uuid!})
        
        // 2017-11-27 02:51:29 +0000: An error occurred: fileAlreadyDeleted [remove(images:) in SyncController.swift, line 64]
        do {
            try SyncServer.session.delete(filesWithUUIDs: imageUuids + discussionUuids)
        } catch (let error) {
            Log.error("An error occurred: \(error)")
            return false
        }
        
        SyncServer.session.sync()
        return true
    }
}

extension SyncController : SyncServerDelegate {
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
                let attr = SyncAttributes(fileUUID: downloadedContentAttributes.fileUUID, mimeType: downloadedContentAttributes.mimeType)
                
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
                } catch (let error) {
                    Log.error("Problems writing merged discussion or uploading: \(error)")
                    uploadConflict.resolveConflict(resolution: errorResolution)
                    return
                }
                
                SyncServer.session.sync()
                
                uploadConflict.resolveConflict(resolution: .rejectContentDownload(.removeAll))
            }
            
        // For now, we're going to prioritize the server operation. We've queued up a local deletion-- seems no loss if we accept the new download. We can always try the deletion again.
        case .uploadDeletion, .both:
            uploadConflict.resolveConflict(resolution: .acceptContentDownload)
        }
    }
    
    func syncServerFileGroupDownloadComplete(group: [DownloadOperation]) {
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

            case .file(let url):
                singleFileDownloadComplete(url:url, attr: operation.attr)
            }
        }
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
    
    func singleFileDownloadComplete(url:SMRelativeLocalURL, attr: SyncAttributes) {
        let (fileTypeString, fileType) = fileTypeFrom(appMetaData: attr.appMetaData)
        
        if let fileTypeString = fileTypeString {
            guard let fileType = fileType else {
                Log.error("Unknown file type: \(fileTypeString)")
                return
            }
            
            switch fileType {
            case .discussion:
                discussionDownloadComplete(url: url, attr: attr)
                
            case .image:
                imageDownloadComplete(url: url, attr: attr)
            }
            
            return
        }
        
        // We don't have type info in the appMetaData-- too early of a file version. Assume it's an image.
        imageDownloadComplete(url: url, attr: attr)
    }
    
    private func imageDownloadComplete(url:SMRelativeLocalURL, attr: SyncAttributes) {
        // The files we get back from the SyncServer are in a temporary location. We own them though, so can move them.
        let newImageURL = FileExtras().newURLForImage()
        do {
            try FileManager.default.moveItem(at: url as URL, to: newImageURL as URL)
        } catch (let error) {
            Log.error("An error occurred moving a file: \(error)")
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

        let imageFileData = FileData(url: newImageURL, mimeType: attr.mimeType, uuid: attr.fileUUID)
        let imageData = ImageData(file: imageFileData, title: title, creationDate: attr.creationDate as NSDate?, discussionUUID: discussionUUID, fileGroupUUID: attr.fileGroupUUID)

        delegate.addLocalImage(syncController: self, imageData: imageData, attr: attr)
        
        delegate.completedAddingLocalImages(syncController: self)
        Progress.session.next()
    }
    
    private func discussionDownloadComplete(url:SMRelativeLocalURL, attr: SyncAttributes) {
        // The files we get back from the SyncServer are in a temporary location. We own them though so can move it.
        let newJSONFileURL = ImageExtras.newJSONFile()
        do {
            try FileManager.default.moveItem(at: url as URL, to: newJSONFileURL as URL)
        } catch (let error) {
            Log.error("An error occurred moving a file: \(error)")
        }
        
        let discussionFileData = FileData(url: newJSONFileURL, mimeType: attr.mimeType, uuid: attr.fileUUID)
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

        case .willStartUploads(numberContentUploads: let numberContentUploads, numberUploadDeletions: let numberUploadDeletions):
        
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
            
        case .singleUploadDeletionComplete:
            Progress.session.next()
            
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
    
#if DEBUG
    public func syncServerSingleFileUploadCompleted(next: @escaping () -> ()) {
        next()
    }
#endif
}
