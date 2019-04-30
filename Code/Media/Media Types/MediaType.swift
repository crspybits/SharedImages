//
//  MediaType.swift
//  SharedImages
//
//  Created by Christopher G Prince on 4/28/19.
//  Copyright © 2019 Spastic Muffin, LLC. All rights reserved.
//

import Foundation

protocol MediaType: FileMediaObjectProtocol where Self: FileMediaObject  {
    // Test the media file we got from the server, if any. Make sure the file is valid and not corrupted in some way.
    func checkForReadProblem(mediaData: MediaData) -> Bool
    
    func setup(mediaData: MediaData)
    
    // Also removes associated discussion. Returns true iff removal was successful.
    static func removeLocalMedia(uuid:String) -> Bool
    
    func remove() throws
}

// Change this when you add a new MediaType
struct MediaTypeExtras {
    static func mediaType(forUUID uuid: String) -> MediaType.Type? {
        guard let obj = FileMediaObject.fetchAbstractObjectWithUUID(uuid) else {
            return nil
        }
        
        switch obj {
        case is ImageMediaObject:
            return ImageMediaObject.self
        case is URLMediaObject:
            return URLMediaObject.self
        default:
            return nil
        }
    }
}

enum AppMetaDataKey: String {
    // deprecated; titles go in the discussion file, for new media.
    case title = "title"
    
    case discussionUUID = "discussionUUID"
    
    // The main active key; when a new file is uploaded, this is used.
    case fileType = "fileType"
}

