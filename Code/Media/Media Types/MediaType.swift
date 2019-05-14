//
//  MediaType.swift
//  SharedImages
//
//  Created by Christopher G Prince on 4/28/19.
//  Copyright © 2019 Spastic Muffin, LLC. All rights reserved.
//

import Foundation

enum MediaTypeSize {
    // Fit to containing cell
    case fit
    
    case large
}

protocol MediaType: FileMediaObjectProtocol where Self: FileMediaObject  {
    var mediaTypeSize: MediaTypeSize {get}
    var originalSize: CGSize? {get}

    // Test the media file we got from the server, if any. Make sure the file is valid and not corrupted in some way. Return true iff there is a read problem.
    func checkForReadProblem(mediaData: MediaData) -> Bool
    
    func setup(mediaData: MediaData)
    
    // Removed based on UUID for media. Also removes associated discussion. Returns true iff removal was successful.
    static func removeLocalMedia(uuid:String) -> Bool
    
    // Remove given a reference to the media object.
    func remove() throws
    
    // Some/all of the uuid's may be for other type objects
    static func loadMediaForActivityViewController(uuids: [String]) -> [Any]
    
    var auxilaryFileUUIDs:[String] {get}
}

// Change this when you add a new MediaType
struct MediaTypeExtras {
    static func mediaType(forUUID uuid: String) -> MediaType.Type? {
        guard let obj = FileObject.fetchObjectWithUUID(uuid) else {
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
    
    // The terms for the `name`s must be pluralizable, e.g., "images".
    static let mediaTypes:[(type: MediaType.Type, name: String)] = [(ImageMediaObject.self, "image"), (URLMediaObject.self, "url")]
    
    static func mediaTypeName(`for` type: MediaType.Type) -> String {
        for mediaType in mediaTypes {
            if type == mediaType.type {
                return mediaType.name
            }
        }
        
        return "media"
    }
    
    static func numberTerm(count: UInt) -> String {
        switch count {
        case 1:
            return "one"
        case 2:
            return "two"
        case 3:
            return "three"
        default:
            return "\(count)"
        }
    }
    
    // Gives a list of media terms summarizing the media. E.g., "urls and image"
    // If includeCounts is true prefixes each term with a count. E.g., "2 urls and 1 image"
    static func namesFor(media: [FileMediaObject], includeCounts: Bool = false) -> String {
        let mediaTypes = media.compactMap {
            MediaTypeExtras.mediaType(forUUID: $0.uuid!)
        }
        
        var numberTypes = 0
        for (mediaType, _) in MediaTypeExtras.mediaTypes {
            let allOfType = mediaTypes.filter {$0 == mediaType}
            if allOfType.isEmpty {
                continue
            }
            
            numberTypes += 1
        }
        
        var description = ""
        var count = 0
        
        for (mediaType, name) in MediaTypeExtras.mediaTypes {
            let allOfType = mediaTypes.filter {$0 == mediaType}
            if allOfType.isEmpty {
                continue
            }
            
            count += 1

            let countTerm = numberTerm(count: UInt(allOfType.count))
            
            var typeTerm = name
            if includeCounts {
                typeTerm = "\(countTerm) \(typeTerm)"
            }
            
            if allOfType.count > 1 {
                typeTerm += "s"
            }
            
            if !description.isEmpty {
                description += " "
            }
            
            if count == numberTypes && count > 1 {
                description += "and \(typeTerm)"
            }
            else if count > 2 {
                description += "\(typeTerm),"
            }
            else {
                description += "\(typeTerm)"
            }
        }
        
        return description
    }
}

enum AppMetaDataKey: String {
    // deprecated; titles go in the discussion file, for new media.
    case title = "title"
    
    case discussionUUID = "discussionUUID"
    
    // The main active key; when a new file is uploaded, this is used.
    case fileType = "fileType"
}

