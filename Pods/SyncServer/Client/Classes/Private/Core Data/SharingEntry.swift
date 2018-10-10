//
//  SharingEntry+CoreDataClass.swift
//  SyncServer
//
//  Created by Christopher G Prince on 9/4/18.
//
//

import Foundation
import CoreData
import SMCoreLib
import SyncServer_Shared

// These represent an index of all sharing groups to which the user belongs.

@objc(SharingEntry)
public class SharingEntry: NSManagedObject, CoreDataModel, AllOperations {
    typealias COREDATAOBJECT = SharingEntry
    
    public static let UUID_KEY = "sharingGroupUUID"

    public class func entityName() -> String {
        return "SharingEntry"
    }
    
    var permission: Permission! {
        get {
            if let permissionInternal = permissionInternal {
                return Permission(rawValue: permissionInternal)
            }
            else {
                return nil
            }
        }
        set {
            if newValue == nil {
                permissionInternal = nil
            }
            else {
                permissionInternal = newValue.rawValue
            }
        }
    }
    
    public class func newObject() -> NSManagedObject {
        let se = CoreData.sessionNamed(Constants.coreDataName).newObject(withEntityName: self.entityName()) as! SharingEntry
        
        // Has the current user been removed from this group?
        se.removedFromGroup = false
        
        // If we are creating the object because the local user created the sharing group, sync with the server is not needed.
        se.syncNeeded = false
        
        se.masterVersion = 0
        se.permission = .read
        
        return se
    }
    
    func toSharingGroup() -> SyncServer.SharingGroup {
        return SyncServer.SharingGroup(sharingGroupUUID: sharingGroupUUID!, sharingGroupName: sharingGroupName, permission: permission, syncNeeded: syncNeeded)
    }
    
    class func fetchObjectWithUUID(uuid:String) -> SharingEntry? {
        let managedObject = CoreData.fetchObjectWithUUID(uuid, usingUUIDKey: UUID_KEY, fromEntityName: self.entityName(), coreDataSession: CoreData.sessionNamed(Constants.coreDataName))
        return managedObject as? SharingEntry
    }
    
    class func masterVersionForUUID(_ uuid: String) -> MasterVersionInt? {
        if let result = fetchObjectWithUUID(uuid: uuid) {
            return result.masterVersion
        }
        else {
            return nil
        }
    }

    // Determine which, if any, sharing groups (a) have been deleted, or (b) have had name changes.
    
    struct Updates {
        let deletedOnServer:[SyncServer.SharingGroup]
        let newSharingGroups:[SyncServer.SharingGroup]
        let updatedSharingGroups:[SyncServer.SharingGroup]
    }
    
    // We're being passed the list of sharing groups in which the user is still a member. (Notably, if a sharing group has been removed from a group, it will not be in this list, so we haven't handle this specially).
    class func update(serverSharingGroups: [SharingGroup]) -> Updates? {
        var deletedOnServer = [SharingGroup]()
        var newSharingGroups = [SharingGroup]()
        var updatedSharingGroups = [SharingGroup]()
        
        serverSharingGroups.forEach { sharingGroup in
            if let sharingGroupUUID = sharingGroup.sharingGroupUUID {
                if let found = fetchObjectWithUUID(uuid: sharingGroupUUID) {
                    if found.sharingGroupName != sharingGroup.sharingGroupName {
                        found.sharingGroupName = sharingGroup.sharingGroupName
                        
                        updatedSharingGroups += [sharingGroup]
                    }
                    if found.masterVersion != sharingGroup.masterVersion {
                        found.masterVersion = sharingGroup.masterVersion!
                        
                        // The master version on the server changed from what we know about. Need to sync with server to get updates.
                        found.syncNeeded = true
                    }
                }
                else {
                    let sharingEntry = SharingEntry.newObject() as! SharingEntry
                    sharingEntry.sharingGroupUUID = sharingGroupUUID
                    sharingEntry.sharingGroupName = sharingGroup.sharingGroupName
                    sharingEntry.masterVersion = sharingGroup.masterVersion!
                    sharingEntry.permission = sharingGroup.permission
                    
                    // This is a sharing group we (the client) didn't know about previously: Need to sync with the server to get files etc. for the sharing group.
                    sharingEntry.syncNeeded = true
                    
                    newSharingGroups += [sharingGroup]
                }
            }
        }
        
        // Now, do the opposite and figure out which sharing groups have been removed or we've been remove from.
        let localSharingGroups = SharingEntry.fetchAll().filter {!$0.removedFromGroup}
        localSharingGroups.forEach { localSharingGroup in
            let filtered = serverSharingGroups.filter {$0.sharingGroupUUID == localSharingGroup.sharingGroupUUID}
            if filtered.count == 0 {
                // We're no longer a member of this sharing group.
                localSharingGroup.removedFromGroup = true
                
                // Not going to mark localSharingGroup as `syncNeeded`. We're not a member of it now-- we'd get an error if we tried to sync with this sharing group.
                
                let deletedSharingGroup = SharingGroup()!
                deletedSharingGroup.sharingGroupUUID = localSharingGroup.sharingGroupUUID
                deletedSharingGroup.sharingGroupName = localSharingGroup.sharingGroupName
                deletedSharingGroup.permission = localSharingGroup.permission
                deletedOnServer += [deletedSharingGroup]
            }
        }
        
        if deletedOnServer.count == 0 && newSharingGroups.count == 0 && updatedSharingGroups.count == 0 {
            return nil
        }
        else {
            return Updates(
                deletedOnServer: SyncServer.SharingGroup.from(sharingGroups: deletedOnServer),
                newSharingGroups: SyncServer.SharingGroup.from(sharingGroups: newSharingGroups),
                updatedSharingGroups: SyncServer.SharingGroup.from(sharingGroups: updatedSharingGroups))
        }
    }
}
