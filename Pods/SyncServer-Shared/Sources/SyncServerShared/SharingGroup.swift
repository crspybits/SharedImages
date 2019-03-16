//
//  SharingGroup.swift
//  SyncServer-Shared
//
//  Created by Christopher G Prince on 8/1/18.
//

import Foundation

#if SERVER
import Kitura
#endif

public class SharingGroup : Codable {
    public init() {}
    
    public var sharingGroupUUID: String?
    
    // The sharing group name is just meta data and is not required to be distinct from other sharing group names. Not making it required either-- some app use cases might not need it.
    public var sharingGroupName: String?
    
    // Has this sharing group been deleted?
    public var deleted: Bool?
    
    // The master version for the sharing group.
    public var masterVersion:MasterVersionInt?
    
    // When returned from an endpoint, gives the calling users permission for the sharing group.
    public var permission:Permission?
    
    // The users who are members of the sharing group.
    public var sharingGroupUsers:[SharingGroupUser]!

    // When returned from an endpoint, for a sharing user, gives the calling users "owning" or "parent" users cloud storage type, or null if an owning user.
    public var cloudStorageType: String?
}

public class SharingGroupUser : Codable {
    public init() {}

    public var name: String!
    
    // Present so that a client call omit themselves from a list of sharing group users presented in the UI.
    public var userId:UserId!
}

public protocol MasterVersionUpdateRequest: RequestMessage {
    var masterVersion:MasterVersionInt! {get}
}

public protocol MasterVersionUpdateResponse: ResponseMessage {
    // If the master version for the sharing group on the server had been previously incremented to a value different than the masterVersion value in the request, this key will be present in the response-- with the new value of the master version. The requested operation was not attempted in this case.
    var masterVersionUpdate:MasterVersionInt? {get set}
}

