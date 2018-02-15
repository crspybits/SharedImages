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

enum SyncControllerEvent {
    case syncStarted
    case syncDone
    case syncError
}

struct ImageData {
    let file: FileData
    let title:String?
    let creationDate: NSDate?
    let discussionUUID:String?
}

struct FileData {
    let url: SMRelativeLocalURL
    let mimeType:String
    
    // This will be non-nil when we have an assigned UUID being downloaded from the server.
    let uuid:String?
}

protocol SyncControllerDelegate : class {
    // Adding a new image-- since images are immutable, this always results from downloading a new image.
    func addLocalImage(syncController:SyncController, imageData: ImageData)
    
    // This will either be for a new discussion (corresponding to a new image) or it will be additional data for an existing discussion (with an existing image).
    func addToLocalDiscussion(syncController:SyncController, discussionData: FileData)
    
    func updateUploadedImageDate(uuid: String, creationDate: NSDate)
    func completedAddingLocalImages()
    
    // Including removing any discussion thread.
    func removeLocalImages(syncController:SyncController, uuids:[String])
    
    func syncEvent(syncController:SyncController, event:SyncControllerEvent)
}

class SyncController {
    private var progressIndicator: ProgressIndicator!
    private var numberDownloads: UInt!
    private var numberDownloadedSoFar: UInt!
    private var numberUploads: UInt!
    private var numberUploadedSoFar: UInt!
    private var syncDone:(()->())?
    
    init() {
        SyncServer.session.delegate = self
        SyncServer.session.eventsDesired = [.syncStarted, .syncDone, .willStartDownloads, .willStartUploads,
                .singleFileUploadComplete, .singleUploadDeletionComplete]
    }
    
    weak var delegate:SyncControllerDelegate!
    
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
        // 12/27/17; Not sending dates to the server-- it establishes the dates.
        var imageAttr = SyncAttributes(fileUUID:image.uuid!, mimeType:image.mimeType!)
        
        var imageAppMetaData = [String: Any]()
        imageAppMetaData[ImageExtras.appMetaDataTitleKey] = image.title
        imageAppMetaData[ImageExtras.appMetaDataDiscussionUUIDKey] = discussion.uuid
        imageAppMetaData[ImageExtras.appMetaDataFileTypeKey] = ImageExtras.FileType.image.rawValue

        imageAttr.appMetaData = dictToJSONString(imageAppMetaData)
        assert(imageAttr.appMetaData != nil)
        
        var discussionAttr = SyncAttributes(fileUUID:discussion.uuid!, mimeType:discussion.mimeType!)
        var discussionAppMetaData = [String: Any]()
        discussionAppMetaData[ImageExtras.appMetaDataFileTypeKey] = ImageExtras.FileType.discussion.rawValue
        discussionAttr.appMetaData = dictToJSONString(discussionAppMetaData)
        assert(discussionAttr.appMetaData != nil)
        
        do {
            try SyncServer.session.uploadImmutable(localFile: image.url!, withAttributes: imageAttr)
            
            // Using uploadCopy for discussions in case the discussion gets updated locally before we complete this sync operation. i.e., discussions are mutable.
            try SyncServer.session.uploadCopy(localFile: discussion.url!, withAttributes: discussionAttr)

            SyncServer.session.sync()
        } catch (let error) {
            Log.error("An error occurred: \(error)")
        }
    }
    
    func update(discussion: Discussion) {
        let discussionAttr = SyncAttributes(fileUUID:discussion.uuid!, mimeType:discussion.mimeType!)
        
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
    func syncServerMustResolveFileDownloadConflict(downloadedFile: SMRelativeLocalURL, downloadedFileAttributes: SyncAttributes, uploadConflict: SyncServerConflict<FileDownloadResolution>) {
    
        let errorResolution: FileDownloadResolution = .acceptFileDownload
        
        switch uploadConflict.conflictType! {
        case .fileUpload:
            // We have discussion content we're trying to upload, and someone else added discussion content. Don't use either our upload or the download directly. Instead merge the content, and make a new upload with the result.
            
            guard let discussion = Discussion.fetchObjectWithUUID(uuid: downloadedFileAttributes.fileUUID),
                let discussionURL = discussion.url as URL?,
                let localDiscussion = FixedObjects(withFile: discussionURL),
                let serverDiscussion = FixedObjects(withFile: downloadedFile as URL) else {
                Log.error("Error! Yark! We had a conflict but had problems. Oh. My.")
                uploadConflict.resolveConflict(resolution: errorResolution)
                return
            }
            
            let (mergedDiscussion, unreadCount) = localDiscussion.merge(with: serverDiscussion)
            let attr = SyncAttributes(fileUUID: downloadedFileAttributes.fileUUID, mimeType: downloadedFileAttributes.mimeType)
            
            // I'm going to use a new file, just in case we have an error writing.
            let mergeURL = ImageExtras.newJSONFile()
            
            do {
                try mergedDiscussion.save(toFile: mergeURL as URL)
                try FileManager.default.removeItem(at: discussionURL)
                
                discussion.url = mergeURL
                discussion.unreadCount = Int32(unreadCount)
                CoreData.sessionNamed(CoreDataExtras.sessionName).saveContext()

                // As before, discussion are mutable-- upload a copy.
                try SyncServer.session.uploadCopy(localFile: mergeURL, withAttributes: attr)
            } catch (let error) {
                Log.error("Problems writing merged discussion or uploading: \(error)")
                uploadConflict.resolveConflict(resolution: errorResolution)
                return
            }
            
            SyncServer.session.sync()
            
            uploadConflict.resolveConflict(resolution: .rejectFileDownload(.removeAll))
        
        // For now, we're going to prioritize the server operation. We've queued up a local deletion-- seems no loss if we accept the new download. We can always try the deletion again.
        case .uploadDeletion, .bothFileUploadAndDeletion:
            uploadConflict.resolveConflict(resolution: .acceptFileDownload)
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
    
    func syncServerSingleFileDownloadComplete(url:SMRelativeLocalURL, attr: SyncAttributes) {
    
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
            title = jsonDict[ImageExtras.appMetaDataTitleKey] as? String
            discussionUUID = jsonDict[ImageExtras.appMetaDataDiscussionUUIDKey] as? String
        }

        let imageFileData = FileData(url: newImageURL, mimeType: attr.mimeType, uuid: attr.fileUUID)
        let imageData = ImageData(file: imageFileData, title: title, creationDate: attr.creationDate as NSDate?, discussionUUID: discussionUUID)
        
        delegate.addLocalImage(syncController: self, imageData: imageData)
        
        delegate.completedAddingLocalImages()
        updateDownloadProgress()
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
        delegate.addToLocalDiscussion(syncController: self, discussionData: discussionFileData)
        
        updateDownloadProgress()
    }
    
    private func updateDownloadProgress(count:UInt = 1) {
        // 12/3/17; We can get here from a call to `shouldDoDeletions`-- when the app is just recovering -- doing deletions on a refresh without having actually done any server interaction. i.e., the client interface has just cached some deletions.
        if numberDownloadedSoFar != nil {
            numberDownloadedSoFar! += count
            Log.msg("numberDownloadedSoFar: \(numberDownloadedSoFar)")
            progressIndicator?.updateProgress(withNumberFilesProcessed: numberDownloadedSoFar)
            if numberDownloadedSoFar! >= numberDownloads {
                progressIndicator?.dismiss()
            }
        }
    }
    
    private func updateUploadProgress(count:UInt = 1) {
        if numberUploadedSoFar != nil {
            numberUploadedSoFar! += count
            progressIndicator?.updateProgress(withNumberFilesProcessed: numberUploadedSoFar)
            if numberUploadedSoFar! >= numberUploads {
                progressIndicator?.dismiss()
            }
        }
    }
    
    // Initially, I wanted to resolve this conflict with `.rejectDownloadDeletion(.keepFileUpload)`. However, this has technical problems. See https://github.com/crspybits/SharedImages/issues/77
    // For now, so that I can complete an initial implementation of discussion threads, I'm going to just use .acceptDownloadDeletion, and have the server take priority on download deletions.
    func syncServerMustResolveDownloadDeletionConflicts(conflicts:[DownloadDeletionConflict]) {
        conflicts.forEach() { (downloadDeletion: SyncAttributes, uploadConflict: SyncServerConflict<DownloadDeletionResolution>) in
            uploadConflict.resolveConflict(resolution: .acceptDownloadDeletion)
        }
    }

    func syncServerShouldDoDeletions(downloadDeletions:[SyncAttributes]) {
        let uuids = downloadDeletions.map({$0.fileUUID!})
        delegate.removeLocalImages(syncController: self, uuids: uuids)
        updateDownloadProgress(count: UInt(uuids.count))
    }
    
    func syncServerErrorOccurred(error:SyncServerError) {
        Log.error("Server error occurred: \(error)")
        
        switch error {
        case .noNetworkError:
            SMCoreLib.Alert.show(withTitle: "The network connection was lost!", message: "Please try again later.")
            
        case .badServerVersion(let actualServerVersion):
            let version = actualServerVersion == nil ? "nil" : actualServerVersion!.rawValue
            SMCoreLib.Alert.show(withTitle: "Bad server version", message: "actualServerVersion: \(version)")
            
        default:
            break
        }
        
        if let delegate = delegate {
            delegate.syncEvent(syncController: self, event: .syncError)
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
        
        let progressIndicatorDelay:DispatchTimeInterval = .milliseconds(500)
        
        switch event {
        case .syncStarted:
            delegate.syncEvent(syncController: self, event: .syncStarted)
            
        case .willStartDownloads(numberFileDownloads: let numberFileDownloads, numberDownloadDeletions: let numberDownloadDeletions):
        
            RosterDevInjectTest.if(TestCases.session.testCrashNextDownload) {[unowned self] in
#if DEBUG
                self.delayedCrash()
#endif
            }
            
            Log.msg("willStartDownloads: Starting ProgressIndicator")

            numberDownloads = numberFileDownloads + numberDownloadDeletions
            numberDownloadedSoFar = 0
            
            // In case there's already one. Seems unlikely, but willStartDownloads can be repeated if we get a master version update.
            // 2/13/18; And while it seems unlikely, I've found a case where it occurs: https://github.com/crspybits/SharedImages/issues/82
            progressIndicator?.dismiss(force: true)
            
            // TESTING
            // TimedCallback.withDuration(30, andCallback: {
            //     Network.session().debugNetworkOff = true
            // })
            // TESTING
            
            // 2/13/18; I'm having problems getting this to actually display the progress indicator in the case of https://github.com/crspybits/SharedImages/issues/82 It turns out it needs an appreciable delay (1ms doesn't work, but 500ms does).
            DispatchQueue.main.asyncAfter(deadline: .now() + progressIndicatorDelay) {[unowned self] in
                self.progressIndicator = ProgressIndicator(filesToDownload: numberFileDownloads, filesToDelete: numberDownloadDeletions, withStopHandler: {
                    SyncServer.session.stopSync()
                })
                self.progressIndicator.show()
            }

        case .willStartUploads(numberFileUploads: let numberFileUploads, numberUploadDeletions: let numberUploadDeletions):
        
            RosterDevInjectTest.if(TestCases.session.testCrashNextUpload) {[unowned self] in
#if DEBUG
                self.delayedCrash()
#endif
            }
        
            Log.msg("willStartUploads: Starting ProgressIndicator")
            numberUploads = numberFileUploads + numberUploadDeletions
            numberUploadedSoFar = 0
            progressIndicator?.dismiss(force: true)
            
            DispatchQueue.main.asyncAfter(deadline: .now() + progressIndicatorDelay) {[unowned self] in
                self.progressIndicator = ProgressIndicator(filesToUpload: numberFileUploads, filesToUploadDelete: numberUploadDeletions, withStopHandler: {
                    SyncServer.session.stopSync()
                })

                self.progressIndicator.show()
            }
            
        case .singleFileUploadComplete(attr: let attr):
            let (_, fileType) = fileTypeFrom(appMetaData: attr.appMetaData)
            if fileType == nil || fileType == .image {
                // Include the nil case because files without types are images-- i.e., they were created before we started typing files in the meta data.
                Log.msg("fileType: \(String(describing: fileType))")
                delegate.updateUploadedImageDate(uuid: attr.fileUUID, creationDate: attr.creationDate! as NSDate)
            }
            
            updateUploadProgress()
            
        case .singleUploadDeletionComplete:
            updateUploadProgress()
            
        case .syncDone:
            delegate.syncEvent(syncController: self, event: .syncDone)
            syncDone?()
            syncDone = nil
        
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
