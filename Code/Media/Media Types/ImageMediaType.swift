//
//  ImageMediaType.swift
//  SharedImages
//
//  Created by Christopher G Prince on 4/28/19.
//  Copyright © 2019 Spastic Muffin, LLC. All rights reserved.
//

import UIKit
import SMCoreLib
import SyncServer_Shared
import SyncServer

extension ImageMediaObject: MediaType {    
    func checkForReadProblem(mediaData: MediaData) -> Bool {
        if let imageFilePath = mediaData.file.url?.path {
            let image = UIImage(contentsOfFile: imageFilePath)
            return image == nil
        }
        else {
            // Image is gone, but we don't have a read problem.
            return false
        }
    }
    
    func setup(mediaData: MediaData) {
        if !readProblem,
            let imageFileName = mediaData.file.url?.lastPathComponent {
            let size = ImageStorage.size(ofImage: imageFileName, withPath: ImageExtras.largeImageDirectoryURL)
            originalHeight = Float(size.height)
            originalWidth = Float(size.width)
        }
    }
    
    // Also removes associated discussion.
    static func removeLocalMedia(uuid:String) -> Bool {
        return FileMediaObject.remove(uuid: uuid)
    }
}
