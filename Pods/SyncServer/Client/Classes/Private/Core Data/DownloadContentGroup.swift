//
//  DownloadContentGroup+CoreDataClass.swift
//  SyncServer
//
//  Created by Christopher G Prince on 4/21/18.
//
//

import Foundation
import CoreData
import SMCoreLib
import SyncServer_Shared

// Groups of download operations-- including appMetaData, file version contents, and deletions. I'm including deletions because it seems reasonable that a file group could have files added and/or deleted, and we'd want to encompass both adding and deleting in the file group unit.

@objc(DownloadContentGroup)
public class DownloadContentGroup: NSManagedObject, CoreDataModel, AllOperations {
    typealias COREDATAOBJECT = DownloadContentGroup
    
    public static let UUID_KEY = "fileGroupUUID"

    public class func entityName() -> String {
        return "DownloadContentGroup"
    }
    
    var status:DownloadFileTracker.Status {
        get {
            return DownloadFileTracker.Status(rawValue: statusRaw!)!
        }
        
        set {
            statusRaw = newValue.rawValue
        }
    }
    
    var dfts:[DownloadFileTracker] {
        if let downloads = downloads, let result = Array(downloads) as?  [DownloadFileTracker] {
            return result
        }
        return []
    }
    
    public class func newObject() -> NSManagedObject {
        let contentGroup = CoreData.sessionNamed(Constants.coreDataName).newObject(
            withEntityName: self.entityName()) as! DownloadContentGroup
        contentGroup.status = .notStarted
        return contentGroup
    }
    
    class func fetchObjectWithUUID(fileGroupUUID:String) -> DownloadContentGroup? {
        let managedObject = CoreData.fetchObjectWithUUID(fileGroupUUID, usingUUIDKey: UUID_KEY, fromEntityName: self.entityName(), coreDataSession: CoreData.sessionNamed(Constants.coreDataName))
        return managedObject as? DownloadContentGroup
    }
    
    // If a DownloadContentGroup exists with this fileGroupUUID, adds this dft to it. Otherwise, creates one and adds it. The case were fileGroupUUID is nil is to deal with not having a fileGroupUUID for a file-- to enable consistency with downloads.
    class func addDownloadFileTracker(_ dft: DownloadFileTracker, to fileGroupUUID:String?) throws {
        if dft.sharingGroupUUID == nil {
            throw SyncServerError.noSharingGroupUUID
        }

        var group:DownloadContentGroup!
        if let fileGroupUUID = fileGroupUUID,
            let dcg = DownloadContentGroup.fetchObjectWithUUID(fileGroupUUID: fileGroupUUID) {
            if dcg.sharingGroupUUID != dft.sharingGroupUUID {
                throw SyncServerError.sharingGroupUUIDInconsistent
            }
            group = dcg
        }
        else {
            group = (DownloadContentGroup.newObject() as! DownloadContentGroup)
            group.sharingGroupUUID = dft.sharingGroupUUID
            group.fileGroupUUID = fileGroupUUID
        }
        
        group.addToDownloads(dft)
    }
    
    // Consider dft's "completed" if they are downloaded or if they are deletions. (Deletions don't require an actual download-- only client action).
    func allDftsCompleted() -> Bool {
        let completed = self.dfts.filter {
            $0.status == .downloaded || $0.operation == .deletion
        }
        return completed.count == self.dfts.count
    }
    
    // Get current downloading DownloadContentGroup or get next if there is not one downloading. Does not do a `perform`.
    static func getNextToDownload() throws -> DownloadContentGroup? {
        var result:DownloadContentGroup?
        
        let dcgs = DownloadContentGroup.fetchAll()
        let downloadingGroups = dcgs.filter { dcg in dcg.status == .downloading }
    
        if downloadingGroups.count > 0 {
            guard downloadingGroups.count == 1 else {
                throw SyncServerError.generic("More than one downloading file group!")
            }
            
            result = downloadingGroups[0]
        }
        else {
            let notStartedGroups = dcgs.filter { dcg in dcg.status == .notStarted }
            
            guard notStartedGroups.count > 0 else {
                // No groups currently being downloaded, and no groups that are not started. That means all groups are downloaded.
                return nil
            }
            
            result = notStartedGroups[0]
        }
        
        return result
    }
    
    func remove()  {        
        CoreData.sessionNamed(Constants.coreDataName).remove(self)
    }
}
