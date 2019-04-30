//
//  MediaHandler.swift
//  SharedImages
//
//  Created by Christopher G Prince on 9/29/18.
//  Copyright © 2018 Spastic Muffin, LLC. All rights reserved.
//

import Foundation
import SyncServer
import SMCoreLib
import SyncServer_Shared

class MediaHandler {
    static let session = MediaHandler()
    
    var syncController = SyncController()

    var syncEventAction:((SyncControllerEvent)->())?
    var completedAddingOrUpdatingLocalMediaAction:(()->())?

    private init() {
        syncController.delegate = self
    }
    
    static func setup() {
        // Force the lazy session to be created (see also https://stackoverflow.com/questions/34667134/implicitly-lazy-static-members-in-swift). s
        _ = MediaHandler.session
    }
    
    func appWillEnterForeground() {
        syncController.appWillEnterForeground()
    }
    
    func appDidEnterBackground() {
        syncController.appDidEnterBackground()
    }
    
    @discardableResult
    func addOrUpdateLocalMedia(newMediaData: MediaData, fileGroupUUID: String?) -> FileMediaObject {
        var theMedia:MediaType!
        
        if newMediaData.file.fileUUID == nil {
            // We're creating a new image at the local user's request.
            theMedia = newMediaData.mediaType.newObjectAndMakeUUID(makeUUID: true, creationDate: newMediaData.creationDate) as? MediaType
        }
        else {
            /* This is a download from the server. There are two cases:
                1) The main download use case: Creating a new media object downloaded from the server (also, possibly "gone" or a read problem).
                2) An error use case: Previously, with "gone" or a read problem, a media object was downloaded another time.
            */
            theMedia = newMediaData.mediaType.fetchObjectWithUUID(newMediaData.file.fileUUID!) as? MediaType
            if theMedia == nil {
                // No existing local image. Must be a first download case from the server.
                theMedia = newMediaData.mediaType.newObjectAndMakeUUID(makeUUID: false, creationDate: newMediaData.creationDate) as? MediaType
                theMedia.uuid = newMediaData.file.fileUUID
            }

            theMedia.readProblem = theMedia.checkForReadProblem(mediaData: newMediaData)
        }

        if theMedia.readProblem {
            // With a read problem, the url is effectively invalid.
            theMedia.url = nil
        }
        else {
            // With download/gone cases, the url will be nil. But, with upload/gone cases, we'll have a valid url.
            theMedia.url = newMediaData.file.url
        }
        
        theMedia.gone = newMediaData.file.gone
        
        theMedia.mimeType = newMediaData.file.mimeType.rawValue
        theMedia.title = newMediaData.title
        theMedia.discussionUUID = newMediaData.discussionUUID
        theMedia.fileGroupUUID = fileGroupUUID
        theMedia.sharingGroupUUID = newMediaData.file.sharingGroupUUID
        theMedia.setup(mediaData: newMediaData)
        
        // Lookup the Discussion and connect it if we have it.
        
        var discussion:DiscussionFileObject?
        
        if let discussionUUID = newMediaData.discussionUUID {
            discussion = DiscussionFileObject.fetchObjectWithUUID(discussionUUID)
        }
        
        if discussion == nil, let fileGroupUUID = newMediaData.fileGroupUUID {
            discussion = DiscussionFileObject.fetchObjectWithFileGroupUUID(fileGroupUUID)
        }
        
        theMedia.discussion = discussion
        
        if let discussion = discussion {
            // 4/17/18; If that discussion has the image title, get that too.
            if newMediaData.title == nil {
                if let url = discussion.url,
                    let fixedObjects = FixedObjects(withFile: url as URL) {
                    theMedia.title = fixedObjects[DiscussionKeys.mediaTitleKey] as? String
                }
                else {
                    Log.error("Could not load discussion!")
                }
            }
        }

        CoreData.sessionNamed(CoreDataExtras.sessionName).saveContext()
        
        return theMedia
    }
    
    enum AddToDiscussion {
        case newLocalDiscussion
        case fromServer
    }
    
    // Three cases: 1) new discussion added locally (uuid of the FileData will be nil), 2) update to existing local discussion (with data from server), and 3) new discussion from server.
    @discardableResult
    func addToLocalDiscussion(discussionData: FileData, type: AddToDiscussion, fileGroupUUID: String?) -> DiscussionFileObject {
        var localDiscussion: DiscussionFileObject!
        var mediaTitle: String?
        
        func newDiscussion() {
            // This is a new discussion, downloaded from the server. We can update the unread count on the discussion with the total discussion content size.
            if let gone = discussionData.gone {
                localDiscussion.gone = gone
            }
            else if let discussionDataURL = discussionData.url,
                let fixedObjects = FixedObjects(withFile: discussionDataURL as URL) {
                localDiscussion.unreadCount = Int32(fixedObjects.count)
                mediaTitle = fixedObjects[DiscussionKeys.mediaTitleKey] as? String
                localDiscussion.gone = nil
                localDiscussion.readProblem = false
            }
            else {
                localDiscussion.readProblem = true
                Log.error("Some error loading new server discussion.")
            }
        }
        
        switch type {
        case .newLocalDiscussion:
            // 1)
            localDiscussion = (DiscussionFileObject.newObjectAndMakeUUID(makeUUID: false) as! DiscussionFileObject)
            localDiscussion.uuid = discussionData.fileUUID
            localDiscussion.sharingGroupUUID = discussionData.sharingGroupUUID
            
            // This is a new *local* discussion. Shouldn't have problems with file corruption.

        case .fromServer:
            if let existingLocalDiscussion = DiscussionFileObject.fetchObjectWithUUID(discussionData.fileUUID!) {
                // 2) Update to existing local discussion-- this is a main use case. I.e., no conflict and we got new discussion message(s) from the server (i.e., from other users(s)).
                
                localDiscussion = existingLocalDiscussion
                existingLocalDiscussion.gone = nil
                existingLocalDiscussion.readProblem = false
                
                // Since we didn't have a conflict, `newFixedObjects` will be a superset of the existing objects.
                if let gone = discussionData.gone {
                    existingLocalDiscussion.gone = gone
                }
                else if let discussionDataURL = discussionData.url,
                    let newFixedObjects = FixedObjects(withFile: discussionDataURL as URL) {
                    
                    // Existing discussion to merge?
                    if let existingDiscussionURL = existingLocalDiscussion.url,
                        let oldFixedObjects = FixedObjects(withFile: existingDiscussionURL as URL) {
                        // We still want to know how many new messages there are.
                        let (_, newCount) = oldFixedObjects.merge(with: newFixedObjects)
                        // Use `+=1` here because there may already be unread messages.
                        existingLocalDiscussion.unreadCount += Int32(newCount)
                        
                        // Remove the existing discussion file
                        do {
                            try FileManager.default.removeItem(at: existingDiscussionURL as URL)
                        } catch (let error) {
                            Log.error("Error removing old discussion file: \(error)")
                        }
                        
                        mediaTitle = newFixedObjects[DiscussionKeys.mediaTitleKey] as? String
                    }
                    else {
                        // Recovering from an error condition: A discussion object exists already, but the file could not previously be downloaded.
                        newDiscussion()
                    }
                }
                else {
                    existingLocalDiscussion.readProblem = true
                    Log.error("Some error loading discussion file.")
                }
            }
            else {
                // 3) New discussion downloaded from server.
                localDiscussion = (DiscussionFileObject.newObjectAndMakeUUID(makeUUID: false) as! DiscussionFileObject)
                localDiscussion.uuid = discussionData.fileUUID
                localDiscussion.sharingGroupUUID = discussionData.sharingGroupUUID
                localDiscussion.gone = nil
                
                newDiscussion()
            }
        } // end switch
        
        localDiscussion.mimeType = discussionData.mimeType.rawValue
        localDiscussion.url = discussionData.url
        localDiscussion.fileGroupUUID = fileGroupUUID

        // Look up and connect the media object if we have one.
        var media:FileMediaObject?
        
        // The two means of getting the media reflect different strategies for doing this over time in SharedImages/SyncServer development.
        
        // See if the media has an asssociated discussionUUID (this is the old style).
        media = FileMediaObject.fetchObjectWithDiscussionUUID(localDiscussion.uuid!)

        // If not, see if a fileGroupUUID connects the discussion and image.
        if media == nil, let fileGroupUUID = localDiscussion.fileGroupUUID {
            media = FileMediaObject.fetchObjectWithFileGroupUUID(fileGroupUUID)
        }
        
        if media != nil {
            localDiscussion.mediaObject = media
            
            // 4/17/18; If this discussion has the image title, set the image title from that.
            if let mediaTitle = mediaTitle {
                media!.title = mediaTitle
            }
        }
        
        CoreData.sessionNamed(CoreDataExtras.sessionName).saveContext()
        
        return localDiscussion
    }
    
    func removeLocalMedia(uuid:String) {
        guard let mediaType = MediaTypeExtras.mediaType(forUUID: uuid) else {
            return
        }
        
        _ = mediaType.removeLocalMedia(uuid: uuid)
    }
}

extension MediaHandler: SyncControllerDelegate {
    func userRemovedFromAlbum(syncController: SyncController, sharingGroup: SyncServer.SharingGroup) {
        var numberErrors = 0
        var numberDeletions = 0
        
        if let media = FileMediaObject.fetchAbstractObjectsWithSharingGroupUUID(sharingGroup.sharingGroupUUID) {
            for mediaObj in media {
                do {
                    // This also removes the associated discussion and media file.
                    try mediaObj.remove()
                    numberDeletions += 1
                } catch (let error) {
                    Log.error("\(error)")
                    numberErrors += 1
                }
            }
            
            var message = ""
            if numberDeletions > 0 {
                if numberDeletions == 1 {
                    message = "\(numberDeletions) media object deleted"
                }
                else {
                    message = "\(numberDeletions) media objects deleted"
                }
            }
            
            if numberErrors > 0 {
                if message.count > 0 {
                    message += " and "
                }
                
                if numberErrors == 1 {
                    message += "\(numberErrors) error"
                }
                else {
                    message += "\(numberDeletions) errors"
                }
            }

            var albumName = " "
            if let sharingGroupName = sharingGroup.sharingGroupName {
                albumName = " '\(sharingGroupName)' "
            }
            
            SMCoreLib.Alert.show(withTitle: "Album\(albumName)Removed", message: message)
        }
    }
    
    func addOrUpdateLocalMedia(syncController: SyncController, mediaData: MediaData, attr: SyncAttributes) {
        // We're making an media object for which there is already a UUID on the server (initial download case), or updating a local media object (error case).
        addOrUpdateLocalMedia(newMediaData: mediaData, fileGroupUUID: attr.fileGroupUUID)
    }
    
    func addToLocalDiscussion(syncController:SyncController, discussionData: FileData, attr: SyncAttributes) {
        addToLocalDiscussion(discussionData: discussionData, type: .fromServer, fileGroupUUID: attr.fileGroupUUID)
    }
    
    func updateUploadedMediaDate(syncController:SyncController, uuid: String, creationDate: NSDate) {
        // We provided the content for the media object, but the server establishes its date of creation. So, update our local media object date/time with the creation date from the server.
        if let media = FileMediaObject.fetchAbstractObjectWithUUID(uuid) {
            media.creationDate = creationDate as NSDate
            media.save()
        }
        else {
            Log.error("Could not find media object for UUID: \(uuid)")
        }
    }
    
    func fileGoneDuringUpload(syncController: SyncController, uuid: String, fileType: Files.FileType?, reason: GoneReason) {
        
        var doMedia = false
        
        if let fileType = fileType {
            switch fileType {
            case .discussion:
                if let discussion = DiscussionFileObject.fetchObjectWithUUID(uuid) {
                    discussion.gone = reason
                    discussion.save()
                }
                else {
                    Log.error("Could not find discussion for UUID: \(uuid)")
                }
                
            case .urlPreviewImage:
                // TODO: Fix this
                assert(false)
                break
                
            case .url, .image:
                doMedia = true
            }
        }
        else {
            // Older files from the original server don't have file type appMetaData. They are images.
            doMedia = true
        }

        if doMedia {
            if let media = FileMediaObject.fetchAbstractObjectWithUUID(uuid) {
                media.gone = reason
                media.save()
            }
            else {
                Log.error("Could not find media for UUID: \(uuid)")
            }
        }
    }

    func removeLocalMedia(syncController: SyncController, uuid: String) {
        removeLocalMedia(uuid: uuid)
    }
    
    func syncEvent(syncController:SyncController, event:SyncControllerEvent) {
        syncEventAction?(event)
    }
    
    func completedAddingOrUpdatingLocalMedia(syncController: SyncController) {
        completedAddingOrUpdatingLocalMediaAction?()
    }

    func redoMediaUpload(syncController: SyncController, forDiscussion attr: SyncAttributes) {
        guard let discussion = DiscussionFileObject.fetchObjectWithUUID(attr.fileUUID) else {
            Log.error("Cannot find discussion for attempted media re-upload.")
            return
        }
        
        guard let media = discussion.mediaObject,
            let mediaURL = media.url, let mediaUUID = media.uuid,
            let mimeTypeRaw = media.mimeType,
            let mimeType = MimeType(rawValue: mimeTypeRaw)  else {
            Log.error("Cannot find media for attempted media re-upload.")
            return
        }
        
        let attr = SyncAttributes(fileUUID: mediaUUID, sharingGroupUUID: attr.sharingGroupUUID, mimeType: mimeType)
        do {
            try SyncServer.session.uploadImmutable(localFile: mediaURL, withAttributes: attr)
            try SyncServer.session.sync(sharingGroupUUID: attr.sharingGroupUUID)
        }
        catch (let error) {
            Log.error("Could not do uploadImmutable for media re-upload: \(error)")
            return
        }
    }
}
