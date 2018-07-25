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
    
    public var sharingGroupId: SharingGroupId!

    // You can give either Permission valued keys or string valued keys.
    public required init?(json: JSON) {
        super.init()
        
        self.permission = Decoder.decodePermission(key: CreateSharingInvitationRequest.permissionKey, json: json)
        self.sharingGroupId = Decoder.decode(int64ForKey: ServerEndpoint.sharingGroupIdKey)(json)
        
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
            ServerEndpoint.sharingGroupIdKey]
    }
    
    public func allKeys() -> [String] {
        return self.nonNilKeys()
    }
    
    public func toJSON() -> JSON? {
        return jsonify([
            Encoder.encodePermission(key: CreateSharingInvitationRequest.permissionKey, value: self.permission),
            ServerEndpoint.sharingGroupIdKey ~~> self.sharingGroupId
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
