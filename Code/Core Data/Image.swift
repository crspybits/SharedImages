//
//  Image+CoreDataClass.swift
//  SharedImages
//
//  Created by Christopher Prince on 3/10/17.
//  Copyright © 2017 Spastic Muffin, LLC. All rights reserved.
//

import Foundation
import CoreData
import SMCoreLib

@objc(Image)
public class Image: NSManagedObject {
    static let CREATION_DATE_KEY = "creationDate"
    static let UUID_KEY = "uuid"
    
    var originalSize:CGSize {
        var originalImageSize = CGSize()

        // Originally, I wasn't storing these sizes, so need to grab & store them here if we can. (Defaults for sizes are -1).
        if originalWidth < 0 || originalHeight < 0 {
            originalImageSize = ImageExtras.sizeFromFile(url: url! as URL)
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
    
    var url:SMRelativeLocalURL? {
        get {
            if urlInternal == nil {
                return nil
            }
            else {
                let url = NSKeyedUnarchiver.unarchiveObject(with: urlInternal! as Data) as? SMRelativeLocalURL
                Assert.If(url == nil, thenPrintThisString: "Image: Yikes: No URL!")
                return url
            }
        }
        
        set {
            if newValue == nil {
                urlInternal = nil
            }
            else {
                urlInternal = NSKeyedArchiver.archivedData(withRootObject: newValue!) as NSData?
            }
        }
    }
    
    class func entityName() -> String {
        return "Image"
    }

    // Only may throw when makeUUIDAndUpload is true.
    class func newObjectAndMakeUUID(makeUUID: Bool, creationDate:NSDate? = nil) -> NSManagedObject {
        let image = CoreData.sessionNamed(CoreDataExtras.sessionName).newObject(withEntityName: self.entityName()) as! Image
        
        if makeUUID {
            image.uuid = UUID.make()
        }
        
        if creationDate == nil {
            image.creationDate = NSDate()
        }
        else {
            image.creationDate = creationDate
        }
        
        return image
    }
    
    class func newObject() -> NSManagedObject {
        return newObjectAndMakeUUID(makeUUID: false)
    }
    
    class func fetchRequestForAllObjects(ascending:Bool) -> NSFetchRequest<NSFetchRequestResult>? {
        var fetchRequest: NSFetchRequest<NSFetchRequestResult>?
        fetchRequest = CoreData.sessionNamed(CoreDataExtras.sessionName).fetchRequest(withEntityName: self.entityName(), modifyingFetchRequestWith: nil)
        
        if fetchRequest != nil {
            let sortDescriptor = NSSortDescriptor(key: CREATION_DATE_KEY, ascending: ascending)
            fetchRequest!.sortDescriptors = [sortDescriptor]
        }
        
        return fetchRequest
    }
    
    class func fetchObjectWithUUID(uuid:String) -> Image? {
        let managedObject = CoreData.fetchObjectWithUUID(uuid, usingUUIDKey: UUID_KEY, fromEntityName: self.entityName(), coreDataSession: CoreData.sessionNamed(CoreDataExtras.sessionName))
        return managedObject as? Image
    }
    
    static func fetchAll() -> [Image] {
        var images:[Image]!

        do {
            images = try CoreData.sessionNamed(CoreDataExtras.sessionName).fetchAllObjects(withEntityName: self.entityName()) as? [Image]
        } catch (let error) {
            Log.error("Error: \(error)")
            assert(false)
        }
        
        return images
    }
}

extension Image : CacheDataSource {
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
        Log.msg("Evicted image from cache.")
    }
#endif
}

