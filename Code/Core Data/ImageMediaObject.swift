//
//  ImageMediaObject.swift
//  SharedImages
//
//  Created by Christopher Prince on 3/10/17.
//  Copyright © 2017 Spastic Muffin, LLC. All rights reserved.
//

import Foundation
import CoreData
import SMCoreLib
import SyncServer_Shared

// 5/13/18-- The discussionUUID is old as of today. The fileGroupUUID property is the new way to connect discussion and image.

@objc(ImageMediaObject)
public class ImageMediaObject: FileMediaObject, FileMediaObjectProtocol {
    var originalSize:CGSize? {
        var originalImageSize = CGSize()

        // Originally, I wasn't storing these sizes, so need to grab & store them here if we can. (Defaults for sizes are -1).
        if originalWidth < 0 || originalHeight < 0 {
            guard !readProblem, let url = url else {
                return nil
            }
            
            originalImageSize = ImageExtras.sizeFromFile(url: url as URL)
            originalWidth = Float(originalImageSize.width)
            originalHeight = Float(originalImageSize.height)
            CoreData.sessionNamed(CoreDataExtras.sessionName).saveContext()
        }
        else {
            originalImageSize.height = CGFloat(originalHeight)
            originalImageSize.width = CGFloat(originalWidth)
        }
        
        return originalImageSize
    }

    override class func entityName() -> String {
        return "ImageMediaObject"
    }
    
    class func newObject() -> NSManagedObject {
        return newObjectAndMakeUUID(makeUUID: false)
    }
    
    class func newObjectAndMakeUUID(makeUUID: Bool, creationDate:NSDate? = nil) -> NSManagedObject {
        return newObjectAndMakeUUID(entityName: self.entityName(), makeUUID: makeUUID, creationDate:creationDate)
    }
    
    override class func fetchObjectWithUUID(_ uuid:String) -> FileObject? {
        return fetchObjectWithUUID(uuid, entityName: entityName())
    }

    class func fetchObjectsWithSharingGroupUUID(_ sharingGroupUUID:String) -> [ImageMediaObject]? {
        return fetchObjectsWithSharingGroupUUID(entityName: entityName(), sharingGroupUUID) as? [ImageMediaObject]
    }
    
    static func fetchAll() -> [ImageMediaObject] {
        var images:[ImageMediaObject]!

        do {
            images = try CoreData.sessionNamed(CoreDataExtras.sessionName).fetchAllObjects(withEntityName: self.entityName()) as? [ImageMediaObject]
        } catch (let error) {
            Log.error("Error: \(error)")
            assert(false)
        }
        
        return images
    }
}

extension ImageMediaObject : CacheDataSource {
    func keyFor(args size:CGSize) -> String {
        // Using as the key:
        // <filename>.<W>x<H>
        let filename = ImageExtras.imageFileName(url: url! as URL)
        return "\(filename).\(size.width)x\(size.height)"
    }
    
    func cacheDataFor(args size:CGSize) -> UIImage {
        return ImageStorage.getImage(ImageExtras.imageFileName(url: url! as URL), of: size, fromIconDirectory: ImageExtras.iconDirectoryURL, withLargeImageDirectory: ImageExtras.largeImageDirectoryURL)
    }
    
    func costFor(_ item: UIImage) -> Int? {
        // An approximation of the memory space used.
        return item.cgImage!.height * item.cgImage!.bytesPerRow
    }

#if DEBUG
    func cachedItem(_ item:UIImage) {}
    func evictedItemFromCache(_ item:UIImage) {
        Log.info("Evicted image from cache.")
    }
#endif
}

