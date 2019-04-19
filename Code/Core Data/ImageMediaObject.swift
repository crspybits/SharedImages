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
public class ImageMediaObject: FileMediaObject {
    static let CREATION_DATE_KEY = "creationDate"
    static let UUID_KEY = "uuid"
    static let DISCUSSION_UUID_KEY = "discussionUUID"
    static let FILE_GROUP_UUID_KEY = "fileGroupUUID"
    static let UNREAD_COUNT = "discussion.unreadCount"
    static let SHARING_GROUP_UUID_KEY = "sharingGroupUUID"
    static let GONE_KEY = "goneReasonInternal"
    static let READ_PROBLEM_KEY = "readProblem"
    static let DISCUSSION_GONE_KEY = "discussion.goneReasonInternal"
    static let DISCUSSION_READ_PROBLEM_KEY = "discussion.readProblem"
    
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
    
    // Either image or associated discussion
    var eitherHasError: Bool {
        let discussionError = discussion?.hasError ?? false
        return hasError || discussionError
    }

    class func entityName() -> String {
        return "ImageMediaObject"
    }

    class func newObjectAndMakeUUID(makeUUID: Bool, creationDate:NSDate? = nil) -> NSManagedObject {
        let image = CoreData.sessionNamed(CoreDataExtras.sessionName).newObject(withEntityName: self.entityName()) as! ImageMediaObject
        
        if makeUUID {
            image.uuid = UUID.make()
        }
        
        if creationDate == nil {
            image.creationDate = NSDate()
        }
        else {
            image.creationDate = creationDate
        }
        
        image.readProblem = false
        
        return image
    }
    
    class func newObject() -> NSManagedObject {
        return newObjectAndMakeUUID(makeUUID: false)
    }
    
    struct SortFilterParams {
        let sortingOrder: Parameters.SortOrder
        let isAscending: Bool
        let unreadCounts: Parameters.UnreadCounts
        let sharingGroupUUID: String
        
        // Errors include "gone" and read problem images/related discussions.
        let includeErrors: Bool
    }
    
    class func fetchRequestForAllObjects(params:SortFilterParams) -> NSFetchRequest<NSFetchRequestResult>? {
        var fetchRequest: NSFetchRequest<NSFetchRequestResult>?
        fetchRequest = CoreData.sessionNamed(CoreDataExtras.sessionName).fetchRequest(withEntityName: self.entityName(), modifyingFetchRequestWith: { request in
            
            var subpredicates = [NSPredicate]()
            
            switch params.unreadCounts {
            case .all:
                break
                
            case .unread:
                subpredicates += [NSPredicate(format: "(%K > 0)", UNREAD_COUNT)]
            }
            
            subpredicates += [NSPredicate(format: "(%K == %@)", SHARING_GROUP_UUID_KEY, params.sharingGroupUUID)]
            
            if !params.includeErrors {
                subpredicates += [NSPredicate(format: "(%K == nil)", GONE_KEY)]
                subpredicates += [NSPredicate(format: "(%K == false)", READ_PROBLEM_KEY)]
                subpredicates += [NSPredicate(format: "(%K == nil)", DISCUSSION_GONE_KEY)]
                subpredicates += [NSPredicate(format: "(%K == false)", DISCUSSION_READ_PROBLEM_KEY)]
            }
            
            if subpredicates.count > 0 {
                let compoundPredicate = NSCompoundPredicate(andPredicateWithSubpredicates: subpredicates)
                request.predicate = compoundPredicate
            }
        })
        
        if fetchRequest != nil {
            var sortDescriptor:NSSortDescriptor!
            
            switch params.sortingOrder {
            case .creationDate:
                sortDescriptor = NSSortDescriptor(key: CREATION_DATE_KEY, ascending: params.isAscending)
            }
            
            fetchRequest!.sortDescriptors = [sortDescriptor]
        }
        
        return fetchRequest
    }
    
    class func fetchObjectsWithSharingGroupUUID(_ sharingGroupUUID:String) -> [ImageMediaObject]? {
        var result:[ImageMediaObject]?
        do {
            result = try CoreData.sessionNamed(CoreDataExtras.sessionName).fetchObjects(withEntityName: self.entityName(), modifyingFetchRequestWith: { fetchRequest in
                fetchRequest.predicate = NSPredicate(format: "(%K == %@)", SHARING_GROUP_UUID_KEY, sharingGroupUUID)
                fetchRequest.sortDescriptors = [NSSortDescriptor(key: CREATION_DATE_KEY, ascending: true)]
            }) as? [ImageMediaObject]
        } catch (let error) {
            Log.error("\(error)")
            return nil
        }

        return result
    }
    
    class func fetchObjectWithUUID(_ uuid:String) -> ImageMediaObject? {
        let managedObject = CoreData.fetchObjectWithUUID(uuid, usingUUIDKey: UUID_KEY, fromEntityName: self.entityName(), coreDataSession: CoreData.sessionNamed(CoreDataExtras.sessionName))
        return managedObject as? ImageMediaObject
    }
    
    class func fetchObjectWithDiscussionUUID(_ discussionUUID:String) -> ImageMediaObject? {
        let managedObject = CoreData.fetchObjectWithUUID(discussionUUID, usingUUIDKey: DISCUSSION_UUID_KEY, fromEntityName: self.entityName(), coreDataSession: CoreData.sessionNamed(CoreDataExtras.sessionName))
        return managedObject as? ImageMediaObject
    }
    
    class func fetchObjectWithFileGroupUUID(_ fileGroupUUID:String) -> ImageMediaObject? {
        let managedObject = CoreData.fetchObjectWithUUID(fileGroupUUID, usingUUIDKey: FILE_GROUP_UUID_KEY, fromEntityName: self.entityName(), coreDataSession: CoreData.sessionNamed(CoreDataExtras.sessionName))
        return managedObject as? ImageMediaObject
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
    
    func save() {
        CoreData.sessionNamed(CoreDataExtras.sessionName).saveContext()
    }
    
    // Also removes associated discussion.
    func remove() throws {
        if let discussion = discussion {
            try discussion.remove()
        }
        
        if let url = url {
            try FileManager.default.removeItem(at: url as URL)
        }
        
        CoreData.sessionNamed(CoreDataExtras.sessionName).remove(self)
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

