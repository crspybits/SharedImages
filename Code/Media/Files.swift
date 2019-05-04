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
    // The specific names of these enum cases are critical: They are stored in appMetaData on the server. Be EXTREMELY careful changing these.
    enum FileType : String {
        // Media file objects-- these have associated discussions.
        case image
        case url
        
        // Optional supplementary file for url media
        case urlPreviewImage
        
        case discussion
        
        static func from(object: FileMediaObject) -> Files.FileType? {
            switch object {
            case is ImageMediaObject:
                return .image
            case is URLMediaObject:
                return .url
            default:
                Log.error("Unknown FileMediaObject type: \(object.self)")
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
