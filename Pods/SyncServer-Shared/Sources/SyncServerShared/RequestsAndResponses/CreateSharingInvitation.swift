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
    public static let sharingPermissionKey = "sharingPermission"
    public var sharingPermission:SharingPermission!

    // You can give either SharingPermission valued keys or string valued keys.
    public required init?(json: JSON) {
        super.init()
        
        self.sharingPermission = Decoder.decodeSharingPermission(key: CreateSharingInvitationRequest.sharingPermissionKey, json: json)
        
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
        return [CreateSharingInvitationRequest.sharingPermissionKey]
    }
    
    public func allKeys() -> [String] {
        return self.nonNilKeys()
    }
    
    public func toJSON() -> JSON? {
        return jsonify([
            Encoder.encodeSharingPermission(key: CreateSharingInvitationRequest.sharingPermissionKey, value: self.sharingPermission)
        ])
    }
}

public extension Gloss.Encoder {
    public static func encodeSharingPermission(key: String, value: SharingPermission?) -> JSON? {
            
        if let value = value {
            return [key : value.rawValue]
        }

        return nil
    }
}

public extension Gloss.Decoder {
    // The sharing permission in the json can be a string or SharingPermission.
    public static func decodeSharingPermission(key: String, json: JSON) -> SharingPermission? {
            
        if let sharingPermissionString = json.valueForKeyPath(keyPath: key) as? String {
            return SharingPermission(rawValue: sharingPermissionString)
        }
        
        if let sharingPermission = json[key] as? SharingPermission? {
            return sharingPermission
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
