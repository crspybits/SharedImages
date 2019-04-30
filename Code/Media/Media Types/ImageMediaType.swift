//
//  ImageMediaType.swift
//  SharedImages
//
//  Created by Christopher G Prince on 4/28/19.
//  Copyright © 2019 Spastic Muffin, LLC. All rights reserved.
//

import UIKit
import SMCoreLib

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
        guard let image = ImageMediaObject.fetchObjectWithUUID(uuid) else {
            Log.error("Cannot find image with UUID: \(uuid)")
            return false
        }
        
        Log.info("Deleting image with uuid: \(uuid)")
        
        var result: Bool = true
        
        // 12/2/17; It's important that the saveContext follow each remove-- See https://github.com/crspybits/SharedImages/issues/61
        do {
            // This also removes the associated discussion.
            try image.remove()
        }
        catch (let error) {
            Log.error("Error removing image: \(error)")
            result = false
        }
        
        CoreData.sessionNamed(CoreDataExtras.sessionName).saveContext()
        return result
    }
}
