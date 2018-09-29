//
//  CreateSharingInvitation.swift
//  Server
//
//  Created by Christopher Prince on 4/9/17.
//
//

import Foundation
import Gloss

#if SERVER
import Kitura
#endif

public class CreateSharingInvitationRequest : NSObject, RequestMessage {
    public static let permissionKey = "permission"
    public var permission:Permission!
    
    // The sharing group to which a user is being invited. The inviting user must have admin permissions in this group.
    public var sharingGroupUUID:String!

    // You can give either Permission valued keys or string valued keys.
    public required init?(json: JSON) {
        super.init()
        
        self.permission = Decoder.decodePermission(key: CreateSharingInvitationRequest.permissionKey, json: json)
        self.sharingGroupUUID = ServerEndpoint.sharingGroupUUIDKey <~~ json
        
#if SERVER
        if !nonNilKeysHaveValues(in: json) {
            return nil
        }
#endif
    }
    
#if SERVER
    public required convenience init?(request: RouterRequest) {
        self.init(json: request.queryParameters)
    }
#endif
    
    public func nonNilKeys() -> [String] {
        return [CreateSharingInvitationRequest.permissionKey,
            ServerEndpoint.sharingGroupUUIDKey]
    }
    
    public func allKeys() -> [String] {
        return self.nonNilKeys()
    }
    
    public func toJSON() -> JSON? {
        return jsonify([
            Encoder.encodePermission(key: CreateSharingInvitationRequest.permissionKey, value: self.permission),
            ServerEndpoint.sharingGroupUUIDKey ~~> self.sharingGroupUUID
        ])
    }
}

public extension Gloss.Encoder {
    public static func encodePermission(key: String, value: Permission?) -> JSON? {
            
        if let value = value {
            return [key : value.rawValue]
        }

        return nil
    }
}

public extension Gloss.Decoder {
    // The permission in the json can be a string or a Permission.
    public static func decodePermission(key: String, json: JSON) -> Permission? {
        if let permissionString = json.valueForKeyPath(keyPath: key) as? String {
            return Permission(rawValue: permissionString)
        }
        
        if let permission = json[key] as? Permission? {
            return permission
        }
        
        return nil
    }
}

public class CreateSharingInvitationResponse : ResponseMessage {
    public static let sharingInvitationUUIDKey = "sharingInvitationUUID"
    public var sharingInvitationUUID:String!
    
    public var responseType: ResponseType {
        return .json
    }
    
    public required init?(json: JSON) {
        self.sharingInvitationUUID = CreateSharingInvitationResponse.sharingInvitationUUIDKey <~~ json
    }
    
    public convenience init?() {
        self.init(json:[:])
    }
    
    // MARK: - Serialization
    public func toJSON() -> JSON? {
        return jsonify([
            CreateSharingInvitationResponse.sharingInvitationUUIDKey ~~> self.sharingInvitationUUID
        ])
    }
}
