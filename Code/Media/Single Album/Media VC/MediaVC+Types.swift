//
//  MediaVC+Types.swift
//  SharedImages
//
//  Created by Christopher G Prince on 5/1/19.
//  Copyright © 2019 Spastic Muffin, LLC. All rights reserved.
//

import Foundation
import SMCoreLib
import SyncServer_Shared

extension MediaVC {
    // TODO: Need to return an enum, with errors as possible values. The Alerts being shown here don't always appear-- e.g., the photo selection window might still be showing. Have the caller show an error alert.
    func createMediaAndDiscussion(newMediaURL: SMRelativeLocalURL, mimeType:String, mediaType: MediaType.Type, userName: String?) -> (media: FileMediaObject, discussion: DiscussionFileObject)? {
        guard let mimeTypeEnum = MimeType(rawValue: mimeType) else {
            SMCoreLib.Alert.show(fromVC: self, withTitle: "Alert!", message: "Unknown mime type: \(mimeType)")
            return nil
        }
        
        guard let newDiscussionUUID = UUID.make(), let fileGroupUUID = UUID.make() else {
            SMCoreLib.Alert.show(fromVC: self, withTitle: "Alert!", message: "Could not create UUID(s)")
            return nil
        }
        
        let mediaFileData = FileData(url: newMediaURL, mimeType: mimeTypeEnum, fileUUID: nil, sharingGroupUUID: sharingGroup.sharingGroupUUID, gone: nil)
        let mediaData = MediaData(file: mediaFileData, title: userName, creationDate: nil, discussionUUID: newDiscussionUUID, fileGroupUUID: fileGroupUUID, mediaType: mediaType)
        
        // We're making a media object that the user of the app added-- we'll generate a new UUID.
        let newMedia = mediaHandler.addOrUpdateLocalMedia(newMediaData: mediaData, fileGroupUUID:fileGroupUUID)
        newMedia.sharingGroupUUID = sharingGroup.sharingGroupUUID
        
        guard let newDiscussionFileData = createEmptyDiscussion(media: newMedia, discussionUUID: newDiscussionUUID, sharingGroupUUID: sharingGroup.sharingGroupUUID, mediaTitle: userName) else {
            try? newMedia.remove()
            CoreData.sessionNamed(CoreDataExtras.sessionName).saveContext()
            return nil
        }
        
        let newDiscussion = mediaHandler.addToLocalDiscussion(discussionData: newDiscussionFileData, type: .newLocalDiscussion, fileGroupUUID: fileGroupUUID)
        newDiscussion.sharingGroupUUID = sharingGroup.sharingGroupUUID
        
        return (newMedia, newDiscussion)
    }
    
    func createImageAndDiscussion(newImageURL: SMRelativeLocalURL, mimeType:String, userName: String?) -> (image: ImageMediaObject, discussion: DiscussionFileObject)? {
        return createMediaAndDiscussion(newMediaURL: newImageURL, mimeType: mimeType, mediaType: ImageMediaObject.self, userName: userName) as? (ImageMediaObject, DiscussionFileObject)
    }
    
    func createURLMediaAndDiscussion(newMediaURL: SMRelativeLocalURL, mimeType:String, userName: String?) -> (urlMedia: URLMediaObject, discussion: DiscussionFileObject)? {
        return createMediaAndDiscussion(newMediaURL: newMediaURL, mimeType: mimeType, mediaType: URLMediaObject.self, userName: userName) as? (URLMediaObject, DiscussionFileObject)
    }
}
