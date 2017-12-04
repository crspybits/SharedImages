//
//  FileExtras.swift
//  SharedNotes
//
//  Created by Christopher Prince on 5/22/16.
//  Copyright © 2016 Spastic Muffin, LLC. All rights reserved.
//

import Foundation

open class FileExtras {
    open static let defaultDirectoryPath = "LargeImages"
    open static let defaultFileExtension = "jpg"
    open static let defaultFilePrefix = "img"
    
    // Change these if you want.
    open var directoryPathFromDocuments:String = FileExtras.defaultDirectoryPath
    open var fileExtension:String = FileExtras.defaultFileExtension
    open var filePrefix:String = FileExtras.defaultFilePrefix
    
    public init() {
    }
    
    open func newURLForImage() ->  SMRelativeLocalURL {
        let directoryURL = FileStorage.url(ofItem: self.directoryPathFromDocuments)
        FileStorage.createDirectoryIfNeeded(directoryURL)
        let newFileName = FileStorage.createTempFileName(inDirectory: directoryURL?.path, withPrefix: self.filePrefix, andExtension: self.fileExtension)
        return SMRelativeLocalURL(withRelativePath: self.directoryPathFromDocuments + "/" + newFileName!, toBaseURLType: .documentsDirectory)!
    }
}
