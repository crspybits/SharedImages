//
//  FileMediaObject+CoreDataClass.swift
//  SharedImages
//
//  Created by Christopher G Prince on 4/18/19.
//  Copyright © 2019 Spastic Muffin, LLC. All rights reserved.
//
//

import Foundation
import CoreData
import SMCoreLib

protocol FileMediaObjectProtocol {
    static func newObjectAndMakeUUID(makeUUID: Bool, creationDate:NSDate?) -> NSManagedObject
    static func fetchObjectWithUUID(_ uuid:String) -> FileMediaObject?
}

@objc(FileMediaObject)
public class FileMediaObject: FileObject {
    static let UNREAD_COUNT = "discussion.unreadCount"
    static let SHARING_GROUP_UUID_KEY = "sharingGroupUUID"
    static let GONE_KEY = "goneReasonInternal"
    static let DISCUSSION_READ_PROBLEM_KEY = "discussion.readProblem"
    static let READ_PROBLEM_KEY = "readProblem"
    static let DISCUSSION_GONE_KEY = "discussion.goneReasonInternal"
    static let CREATION_DATE_KEY = "creationDate"
    static let DISCUSSION_UUID_KEY = "discussionUUID"
    static let FILE_GROUP_UUID_KEY = "fileGroupUUID"

    // `private` so that inheriting classes don't use or inherit this.
    private class func entityName() -> String {
        return "FileMediaObject"
    }
    
    class func newObjectAndMakeUUID(entityName: String, makeUUID: Bool, creationDate:NSDate? = nil) -> NSManagedObject {
        let image = CoreData.sessionNamed(CoreDataExtras.sessionName)
            .newObject(withEntityName: entityName) as! FileMediaObject
        
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
    
    // Either media or associated discussion
    var eitherHasError: Bool {
        let discussionError = discussion?.hasError ?? false
        return hasError || discussionError
    }
    
    class func fetchAbstractObjectWithUUID(_ uuid:String) -> FileMediaObject? {
        let managedObject = CoreData.fetchObjectWithUUID(uuid, usingUUIDKey: UUID_KEY, fromEntityName: self.entityName(), coreDataSession: CoreData.sessionNamed(CoreDataExtras.sessionName))
        return managedObject as? FileMediaObject
    }
    
    static func fetchAllAbstractObjects() -> [FileMediaObject] {
        var fileMediaObjects:[FileMediaObject]!

        do {
            fileMediaObjects = try CoreData.sessionNamed(CoreDataExtras.sessionName).fetchAllObjects(
                withEntityName: self.entityName()) as? [FileMediaObject]
        } catch (let error) {
            Log.error("Error: \(error)")
            assert(false)
        }
        
        return fileMediaObjects
    }
    
    class func fetchObjectWithDiscussionUUID(_ discussionUUID:String) -> FileMediaObject? {
        let managedObject = CoreData.fetchObjectWithUUID(discussionUUID, usingUUIDKey: DISCUSSION_UUID_KEY, fromEntityName: self.entityName(), coreDataSession: CoreData.sessionNamed(CoreDataExtras.sessionName))
        return managedObject as? FileMediaObject
    }
    
    class func fetchObjectWithFileGroupUUID(_ fileGroupUUID:String) -> FileMediaObject? {
        let managedObject = CoreData.fetchObjectWithUUID(fileGroupUUID, usingUUIDKey: FILE_GROUP_UUID_KEY, fromEntityName: self.entityName(), coreDataSession: CoreData.sessionNamed(CoreDataExtras.sessionName))
        return managedObject as? FileMediaObject
    }
    
    class func fetchObjectsWithSharingGroupUUID(entityName: String, _ sharingGroupUUID:String) -> [FileMediaObject]? {
        var result:[FileMediaObject]?
        do {
            result = try CoreData.sessionNamed(CoreDataExtras.sessionName).fetchObjects(withEntityName: entityName, modifyingFetchRequestWith: { fetchRequest in
                    fetchRequest.predicate = NSPredicate(format: "(%K == %@)", SHARING_GROUP_UUID_KEY, sharingGroupUUID)
                    fetchRequest.sortDescriptors = [NSSortDescriptor(key: CREATION_DATE_KEY, ascending: true)]
                }) as? [FileMediaObject]
        } catch (let error) {
            Log.error("\(error)")
            return nil
        }

        return result
    }
    
    class func fetchAbstractObjectsWithSharingGroupUUID(_ sharingGroupUUID:String) -> [FileMediaObject]? {
        return fetchObjectsWithSharingGroupUUID(entityName: entityName(), sharingGroupUUID)
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
    
    static func remove(uuid:String) -> Bool {
        guard let media = FileMediaObject.fetchAbstractObjectWithUUID(uuid) else {
            Log.error("Cannot find file media object with UUID: \(uuid)")
            return false
        }
        
        Log.info("Deleting file media object with uuid: \(uuid)")
        
        var result: Bool = true
        
        // 12/2/17; It's important that the saveContext follow each remove-- See https://github.com/crspybits/SharedImages/issues/61
        do {
            // This also removes the associated discussion.
            try media.remove()
        }
        catch (let error) {
            Log.error("Error removing media: \(error)")
            result = false
        }
        
        CoreData.sessionNamed(CoreDataExtras.sessionName).saveContext()
        return result
    }
}
