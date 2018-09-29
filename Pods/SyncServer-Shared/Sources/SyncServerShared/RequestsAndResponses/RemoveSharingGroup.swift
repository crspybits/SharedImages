//
//  RemoveSharingGroup.swift
//  SyncServer-Shared
//
//  Created by Christopher G Prince on 8/1/18.
//

import Foundation
import Gloss

#if SERVER
import Kitura
#endif

public class RemoveSharingGroupRequest : NSObject, RequestMessage, MasterVersionUpdateRequest {
    public var masterVersion: MasterVersionInt!
    
    public var sharingGroupUUID:String!
    
#if SERVER
    public required convenience init?(request: RouterRequest) {
        self.init(json: request.queryParameters)
    }
#endif
    
    public required init?(json: JSON) {
        super.init()
        self.sharingGroupUUID = ServerEndpoint.sharingGroupUUIDKey <~~ json
        self.masterVersion = Decoder.decode(int64ForKey: ServerEndpoint.masterVersionKey)(json)
        
        if !nonNilKeysHaveValues(in: json) {
            return nil
        }
    }
    
    public func toJSON() -> JSON? {
        return jsonify([
            ServerEndpoint.sharingGroupUUIDKey ~~> self.sharingGroupUUID,
            ServerEndpoint.masterVersionKey ~~> self.masterVersion
        ])
    }
    
    public func nonNilKeys() -> [String] {
        return [ServerEndpoint.sharingGroupUUIDKey, ServerEndpoint.masterVersionKey]
    }
    
    public func allKeys() -> [String] {
        return self.nonNilKeys()
    }
}

public class RemoveSharingGroupResponse : ResponseMessage, MasterVersionUpdateResponse {
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
