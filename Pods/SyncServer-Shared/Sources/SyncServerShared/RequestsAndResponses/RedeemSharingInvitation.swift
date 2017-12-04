//
//  RedeemSharingInvitation.swift
//  Server
//
//  Created by Christopher Prince on 4/12/17.
//
//

import Foundation
import Gloss

#if SERVER
import Kitura
#endif

public class RedeemSharingInvitationRequest : NSObject, RequestMessage {
    public static let sharingInvitationUUIDKey = "sharingInvitationUUID"
    public var sharingInvitationUUID:String!

    public required init?(json: JSON) {
        super.init()
        
        self.sharingInvitationUUID = RedeemSharingInvitationRequest.sharingInvitationUUIDKey <~~ json

#if SERVER
        if !self.propertiesHaveValues(propertyNames: self.nonNilKeys()) {
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
        return [RedeemSharingInvitationRequest.sharingInvitationUUIDKey]
    }
    
    public func allKeys() -> [String] {
        return self.nonNilKeys()
    }
    
    public func toJSON() -> JSON? {
        return jsonify([
            RedeemSharingInvitationRequest.sharingInvitationUUIDKey ~~> self.sharingInvitationUUID
        ])
    }
}

public class RedeemSharingInvitationResponse : ResponseMessage {
    public var responseType: ResponseType {
        return .json
    }
    
    public required init?(json: JSON) {
    }
    
    public convenience init?() {
        self.init(json:[:])
    }
    
    // MARK: - Serialization
    public func toJSON() -> JSON? {
        return jsonify([
        ])
    }
}
