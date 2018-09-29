//
//  SharingGroup.swift
//  SyncServer-Shared
//
//  Created by Christopher G Prince on 8/1/18.
//

import Foundation
import Gloss

#if SERVER
import Kitura
#endif

public class SharingGroup : Gloss.Encodable, Gloss.Decodable {
    public var sharingGroupUUID: String?
    
    // The sharing group name is just meta data and is not required to be distinct from other sharing group names. Not making it required either-- some app use cases might not need it.
    public static let sharingGroupNameKey = "sharingGroupName"
    public var sharingGroupName: String?
    
    // Has this sharing group been deleted?
    public static let deletedKey = "deleted"
    public var deleted: Bool?
    
    // The master version for the sharing group.
    public static let masterVersionKey = "masterVersion"
    public var masterVersion:MasterVersionInt?
    
    // When returned from an endpoint, gives the calling users permission for the sharing group.
    public static let permissionKey = "permission"
    public var permission:Permission?
    
    // The users who are members of the sharing group.
    public static let sharingGroupUsersKey = "sharingGroupUsers"
    public var sharingGroupUsers:[SharingGroupUser]!

    required public init?(json: JSON) {
        self.sharingGroupName = SharingGroup.sharingGroupNameKey <~~ json
        self.sharingGroupUUID = ServerEndpoint.sharingGroupUUIDKey <~~ json
        self.deleted = SharingGroup.deletedKey <~~ json
        self.masterVersion = Decoder.decode(int64ForKey: IndexResponse.masterVersionKey)(json)
        self.permission = Decoder.decodePermission(key: SharingGroup.permissionKey, json: json)
        self.sharingGroupUsers = SharingGroup.sharingGroupUsersKey <~~ json
    }
    
    public convenience init?() {
        self.init(json:[:])
    }
    
    public func toJSON() -> JSON? {
        return jsonify([
            SharingGroup.sharingGroupNameKey ~~> self.sharingGroupName,
            ServerEndpoint.sharingGroupUUIDKey ~~> self.sharingGroupUUID,
            SharingGroup.deletedKey ~~> self.deleted,
            IndexResponse.masterVersionKey ~~> self.masterVersion,
            Encoder.encodePermission(key: SharingGroup.permissionKey, value: self.permission),
            SharingGroup.sharingGroupUsersKey ~~> self.sharingGroupUsers
        ])
    }
}

public class SharingGroupUser : Gloss.Encodable, Gloss.Decodable {
    public static let nameKey = "name"
    public var name: String!
    
    // Present so that a client call omit themselves from a list of sharing group users presented in the UI.
    public static let userIdKey = "userId"
    public var userId:UserId!

    required public init?(json: JSON) {
        self.name = SharingGroupUser.nameKey <~~ json
        userId = Decoder.decode(int64ForKey: SharingGroupUser.userIdKey)(json)
    }
    
    public convenience init?() {
        self.init(json:[:])
    }
    
    public func toJSON() -> JSON? {
        return jsonify([
            SharingGroupUser.nameKey ~~> self.name,
            SharingGroupUser.userIdKey ~~> userId
        ])
    }
}

public protocol MasterVersionUpdateRequest: RequestMessage {
    var masterVersion:MasterVersionInt! {get}
}

public protocol MasterVersionUpdateResponse: ResponseMessage {
    // If the master version for the sharing group on the server had been previously incremented to a value different than the masterVersion value in the request, this key will be present in the response-- with the new value of the master version. The requested operation was not attempted in this case.
    var masterVersionUpdate:MasterVersionInt? {get set}
}

