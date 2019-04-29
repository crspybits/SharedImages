//
//  NewFiles.swift
//  SharedImages
//
//  Created by Christopher G Prince on 4/28/19.
//  Copyright © 2019 Spastic Muffin, LLC. All rights reserved.
//

import Foundation
import SMCoreLib

open class NewFiles {
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
