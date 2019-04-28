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

@objc(FileMediaObject)
public class FileMediaObject: FileObject {
    static let UNREAD_COUNT = "discussion.unreadCount"
    static let SHARING_GROUP_UUID_KEY = "sharingGroupUUID"
    static let GONE_KEY = "goneReasonInternal"
    static let DISCUSSION_READ_PROBLEM_KEY = "discussion.readProblem"
    static let READ_PROBLEM_KEY = "readProblem"
    static let DISCUSSION_GONE_KEY = "discussion.goneReasonInternal"
    static let CREATION_DATE_KEY = "creationDate"

    // `private` so that inheriting classes don't use or inherit this.
    private class func entityName() -> String {
        return "FileMediaObject"
    }
    
    // Either media or associated discussion
    var eitherHasError: Bool {
        let discussionError = discussion?.hasError ?? false
        return hasError || discussionError
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
}
