//
//  ImagesHandler.swift
//  SharedImages
//
//  Created by Christopher G Prince on 9/29/18.
//  Copyright © 2018 Spastic Muffin, LLC. All rights reserved.
//

import Foundation
import SyncServer
import SMCoreLib

class ImagesHandler {
    var syncController = SyncController()

    var syncEventAction:((SyncControllerEvent)->())?
    var completedAddingLocalImagesAction:(()->())?

    init() {
        syncController.delegate = self
    }
    
    @discardableResult
    func addLocalImage(newImageData: ImageData, fileGroupUUID: String?) -> Image {
        var newImage:Image!
        
        if newImageData.file.fileUUID == nil {
            // We're creating a new image at the user's request.
            newImage = Image.newObjectAndMakeUUID(makeUUID: true, creationDate: newImageData.creationDate) as? Image
        }
        else {
            newImage = Image.newObjectAndMakeUUID(makeUUID: false, creationDate: newImageData.creationDate) as? Image
            newImage.uuid = newImageData.file.fileUUID
        }

        newImage.url = newImageData.file.url
        newImage.mimeType = newImageData.file.mimeType.rawValue
        newImage.title = newImageData.title
        newImage.discussionUUID = newImageData.discussionUUID
        newImage.fileGroupUUID = fileGroupUUID
        newImage.sharingGroupUUID = newImageData.file.sharingGroupUUID
        
        let imageFileName = newImageData.file.url.lastPathComponent
        let size = ImageStorage.size(ofImage: imageFileName, withPath: ImageExtras.largeImageDirectoryURL)
        newImage.originalHeight = Float(size.height)
        newImage.originalWidth = Float(size.width)
        
        // Lookup the Discussion and connect it if we have it.
        
        var discussion:Discussion?
        
        if let discussionUUID = newImageData.discussionUUID {
            discussion = Discussion.fetchObjectWithUUID(discussionUUID)
        }
        
        if discussion == nil, let fileGroupUUID = newImageData.fileGroupUUID {
            discussion = Discussion.fetchObjectWithFileGroupUUID(fileGroupUUID)
        }
        
        newImage.discussion = discussion
        
        if discussion != nil {
            // 4/17/18; If that discussion has the image title, get that too.
            if newImageData.title == nil {
                if let url = discussion!.url,
                    let fixedObjects = FixedObjects(withFile: url as URL) {
                    newImage.title = fixedObjects[DiscussionKeys.imageTitleKey] as? String
                }
                else {
                    Log.error("Could not load discussion!")
                }
            }
        }

        CoreData.sessionNamed(CoreDataExtras.sessionName).saveContext()
        
        return newImage
    }
    
    enum AddToDiscussion {
        case newLocalDiscussion
        case fromServer
    }
    
    // Three cases: 1) new discussion added locally (uuid of the FileData will be nil), 2) update to existing local discussion (with data from server), and 3) new discussion from server.
    @discardableResult
    func addToLocalDiscussion(discussionData: FileData, type: AddToDiscussion, fileGroupUUID: String?) -> Discussion {
        var localDiscussion: Discussion!
        var imageTitle: String?
        
        switch type {
        case .newLocalDiscussion:
            // 1)
            localDiscussion = (Discussion.newObjectAndMakeUUID(makeUUID: false) as! Discussion)
            localDiscussion.uuid = discussionData.fileUUID
            localDiscussion.sharingGroupUUID = discussionData.sharingGroupUUID

        case .fromServer:
            if let existingLocalDiscussion = Discussion.fetchObjectWithUUID(discussionData.fileUUID!) {
                // 2) Update to existing local discussion-- this is a main use case. I.e., no conflict and we got new discussion message(s) from the server (i.e., from other users(s)).
                
                localDiscussion = existingLocalDiscussion
                
                // Since we didn't have a conflict, `newFixedObjects` will be a superset of the existing objects.
                if let newFixedObjects = FixedObjects(withFile: discussionData.url as URL),
                    let existingDiscussionURL = existingLocalDiscussion.url,
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
                    
                    imageTitle = newFixedObjects[DiscussionKeys.imageTitleKey] as? String
                }
            }
            else {
                // 3) New discussion downloaded from server.
                localDiscussion = (Discussion.newObjectAndMakeUUID(makeUUID: false) as! Discussion)
                localDiscussion.uuid = discussionData.fileUUID
                localDiscussion.sharingGroupUUID = discussionData.sharingGroupUUID
                
                // This is a new discussion, downloaded from the server. We can update the unread count on the discussion with the total discussion content size.
                if let fixedObjects = FixedObjects(withFile: discussionData.url as URL) {
                    localDiscussion.unreadCount = Int32(fixedObjects.count)
                    imageTitle = fixedObjects[DiscussionKeys.imageTitleKey] as? String
                }
                else {
                    Log.error("Could not load discussion!")
                }
            }
        }
        
        localDiscussion.mimeType = discussionData.mimeType.rawValue
        localDiscussion.url = discussionData.url
        localDiscussion.fileGroupUUID = fileGroupUUID

        // Look up and connect the Image if we have one.
        var image:Image?
        
        // The two means of getting the image reflect different strategies for doing this over time in SharedImages/SyncServer development.
        
        // See if the image has an asssociated discussionUUID
        image = Image.fetchObjectWithDiscussionUUID(localDiscussion.uuid!)

        // If not, see if a fileGroupUUID connects the discussion and image.
        if image == nil, let fileGroupUUID = localDiscussion.fileGroupUUID {
            image = Image.fetchObjectWithFileGroupUUID(fileGroupUUID)
        }
        
        if image != nil {
            localDiscussion.image = image
            
            // 4/17/18; If this discussion has the image title, set the image title from that.
            if let imageTitle = imageTitle {
                image!.title = imageTitle
            }
        }
        
        CoreData.sessionNamed(CoreDataExtras.sessionName).saveContext()
        UnreadCountBadge.update()
        
        return localDiscussion
    }
    
    func removeLocalImages(uuids:[String]) {
        ImageExtras.removeLocalImages(uuids:uuids)
    }
}

extension ImagesHandler: SyncControllerDelegate {
    func userRemovedFromAlbum(syncController: SyncController, sharingGroupUUID: String) {
        if let images = Image.fetchObjectsWithSharingGroupUUID(sharingGroupUUID) {
            for image in images {
                do {
                    // This also removes the associated discussion and image file.
                    try image.remove()
                } catch (let error) {
                    Log.error("\(error)")
                }
            }
        }
    }
    
    func addLocalImage(syncController:SyncController, imageData: ImageData, attr: SyncAttributes) {
        // We're making an image for which there is already a UUID on the server.
        addLocalImage(newImageData: imageData, fileGroupUUID: attr.fileGroupUUID)
    }
    
    func addToLocalDiscussion(syncController:SyncController, discussionData: FileData, attr: SyncAttributes) {
        addToLocalDiscussion(discussionData: discussionData, type: .fromServer, fileGroupUUID: attr.fileGroupUUID)
    }
    
    func updateUploadedImageDate(syncController:SyncController, uuid: String, creationDate: NSDate) {
        // We provided the content for the image, but the server establishes its date of creation. So, update our local image date/time with the creation date from the server.
        if let image = Image.fetchObjectWithUUID(uuid) {
            image.creationDate = creationDate as NSDate
            image.save()
        }
        else {
            Log.error("Could not find image for UUID: \(uuid)")
        }
    }

    func removeLocalImages(syncController: SyncController, uuids: [String]) {
        removeLocalImages(uuids: uuids)
    }
    
    func syncEvent(syncController:SyncController, event:SyncControllerEvent) {
        syncEventAction?(event)
    }
    
    func completedAddingLocalImages(syncController:SyncController) {
        completedAddingLocalImagesAction?()
    }
    
    func redoImageUpload(syncController: SyncController, forDiscussion attr: SyncAttributes) {
        guard let discussion = Discussion.fetchObjectWithUUID(attr.fileUUID) else {
            Log.error("Cannot find discussion for attempted image re-upload.")
            return
        }
        
        guard let image = discussion.image, let imageURL = image.url, let imageUUID = image.uuid else {
            Log.error("Cannot find image for attempted image re-upload.")
            return
        }
        
        let attr = SyncAttributes(fileUUID: imageUUID, sharingGroupUUID: attr.sharingGroupUUID, mimeType: .jpeg)
        do {
            try SyncServer.session.uploadImmutable(localFile: imageURL, withAttributes: attr)
            try SyncServer.session.sync(sharingGroupUUID: attr.sharingGroupUUID)
        }
        catch (let error) {
            Log.error("Could not do uploadImmutable for image re-upload: \(error)")
            return
        }
    }
}
