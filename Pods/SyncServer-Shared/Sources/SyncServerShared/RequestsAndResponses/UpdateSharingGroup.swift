//
//  UpdateSharingGroup.swift
//  SyncServer-Shared
//
//  Created by Christopher G Prince on 8/4/18.
//

import Foundation
import Gloss

#if SERVER
import Kitura
#endif

public class UpdateSharingGroupRequest : NSObject, RequestMessage, MasterVersionUpdateRequest {
    public var masterVersion:MasterVersionInt!

    // I'm having problems uploading complex objects in url parameters. So not sending a SharingGroup object yet. If I need to do this, looks like I'll have to use the request body and am not doing that yet.
    public var sharingGroupUUID:String!
    
    public static let sharingGroupNameKey = "sharingGroupName"
    public var sharingGroupName: String?
    
#if SERVER
    public required convenience init?(request: RouterRequest) {
        self.init(json: request.queryParameters)
    }
#endif
    
    public required init?(json: JSON) {
        super.init()
        self.sharingGroupUUID = ServerEndpoint.sharingGroupUUIDKey <~~ json
        self.sharingGroupName = UpdateSharingGroupRequest.sharingGroupNameKey <~~ json
        self.masterVersion = Decoder.decode(int64ForKey: ServerEndpoint.masterVersionKey)(json)
        
        if !nonNilKeysHaveValues(in: json) {
            return nil
        }
    }
    
    public func toJSON() -> JSON? {
        return jsonify([
            ServerEndpoint.sharingGroupUUIDKey ~~> self.sharingGroupUUID,
            UpdateSharingGroupRequest.sharingGroupNameKey ~~> self.sharingGroupName,
            ServerEndpoint.masterVersionKey ~~> self.masterVersion
        ])
    }
    
    public func nonNilKeys() -> [String] {
        return [ServerEndpoint.sharingGroupUUIDKey, UpdateSharingGroupRequest.sharingGroupNameKey,
            ServerEndpoint.masterVersionKey]
    }
    
    public func allKeys() -> [String] {
        return self.nonNilKeys()
    }
}

public class UpdateSharingGroupResponse : ResponseMessage, MasterVersionUpdateResponse {
    public var masterVersionUpdate: MasterVersionInt?
    
    public var responseType: ResponseType {
        return .json
    }
    
    public required init?(json: JSON) {
        self.masterVersionUpdate = Decoder.decode(int64ForKey: ServerEndpoint.masterVersionUpdateKey)(json)
    }
    
    public convenience init?() {
        self.init(json:[:])
    }
    
    // MARK: - Serialization
    public func toJSON() -> JSON? {
        return jsonify([
            ServerEndpoint.masterVersionUpdateKey ~~> self.masterVersionUpdate
        ])
    }
}
