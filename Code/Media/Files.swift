//
//  NewFiles.swift
//  SharedImages
//
//  Created by Christopher G Prince on 4/28/19.
//  Copyright © 2019 Spastic Muffin, LLC. All rights reserved.
//

import Foundation
import SMCoreLib
import SyncServer

struct Files {
    // The specific names of these FileType enum cases are critical: They are stored in appMetaData on the server. Be EXTREMELY careful changing these.
    enum FileType : String {
        // Media file objects-- these have associated discussions.
        case image
        case url
        
        // Optional supplementary image file for url media
        case urlPreviewImage
        
        // Every media file object has an associated discussion file.
        case discussion
        
        // MARK: Helper methods & types for enum
        
        enum SyncType {
            case immutable
            case copy
        }
        
        var uploadSyncType:SyncType {
            switch self {
            case .image, .url, .urlPreviewImage:
                return .immutable
            
            // Discussions can change; upload as copy.
            case .discussion:
                return .copy
            }
        }
        
        static func from(object: FileObject) -> Files.FileType? {
            switch object {
            case is ImageMediaObject:
                return .image
            case is URLMediaObject:
                return .url
            case _ where object.gone == nil:
                return .urlPreviewImage
            case is DiscussionFileObject:
                return .discussion
            default:
                Log.error("Unknown FileObject type: \(object.self)")
                return nil
            }
        }
        
        static func from(appMetaData:String?) -> (fileTypeString: String?, Files.FileType?) {
            if let appMetaData = appMetaData,
                let jsonDict = appMetaData.jsonStringToDict(),
                let fileTypeString = jsonDict[AppMetaDataKey.fileType.rawValue] as? String {
                
                if let fileType = Files.FileType(rawValue: fileTypeString) {
                    return (fileTypeString, fileType)
                }
                
                return (fileTypeString, nil)
            }
            
            return (nil, nil)
        }
        
        static func isMedia(attr: SyncAttributes) -> Bool {
            let (fileTypeString, fileType) = from(appMetaData: attr.appMetaData)
            if let fileTypeString = fileTypeString {
                guard let fileType = fileType else {
                    Log.error("Unknown file type: \(fileTypeString)")
                    return false
                }
                
                switch fileType {
                case .discussion:
                    return false
                    
                case .urlPreviewImage:
                    return false
                    
                case .image, .url:
                    break
                }
            }
            
            return true
        }
    }
    
    static let discussionsDirectoryPath = "Discussions"

    // This directory is for various kinds of images, including media images and the images (including icons) for URL LinkPreviews. Really, "LargeImages" is a misnomer now (as of 5/4/19). It's really more "PersistentImages"-- images that are uploaded/downloaded to the server.
    public static let largeImagesDirectoryPath = "LargeImages"
    
    public static let imageFileExtension = "jpg"
    public static let imageFilePrefix = "img"
    
    public static let urlFilesDirectoryPath = "URLFiles"
    public static let urlFileExtension = "url"
    public static let urlFilePrefix = "url"
    
    private static func newURL(directoryPath: String, filePrefix: String, fileExtension: String) -> SMRelativeLocalURL {
        let directoryURL = FileStorage.url(ofItem: directoryPath)
        FileStorage.createDirectoryIfNeeded(directoryURL)
        let newFileName = FileStorage.createTempFileName(inDirectory: directoryURL?.path, withPrefix: filePrefix, andExtension: fileExtension)
        return SMRelativeLocalURL(withRelativePath: directoryPath + "/" + newFileName!, toBaseURLType: .documentsDirectory)!
    }
    
    static func newURLForImage() -> SMRelativeLocalURL {
        return newURL(directoryPath: largeImagesDirectoryPath, filePrefix: imageFilePrefix, fileExtension: imageFileExtension)
    }
    
    static func newURLForURLFile() -> SMRelativeLocalURL {
        return newURL(directoryPath: urlFilesDirectoryPath, filePrefix: urlFilePrefix, fileExtension: urlFileExtension)
    }
    
    static func newJSONFile() -> SMRelativeLocalURL {
        return newURL(directoryPath: discussionsDirectoryPath, filePrefix: "FileObjects", fileExtension: "json")
    }
}
