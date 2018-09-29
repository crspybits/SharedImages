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
    // No master version here: The client doesn't yet have information about relevant sharing group that it needs to keep up to date. So, why bother?
    
    public static let sharingInvitationUUIDKey = "sharingInvitationUUID"
    public var sharingInvitationUUID:String!

    // This must be present when redeeming an invitation: a) using an owning account, and b) that owning account type needs a cloud storage folder (e.g., Google Drive).
    public var cloudFolderName:String?

    public required init?(json: JSON) {
        super.init()
        
        self.sharingInvitationUUID = RedeemSharingInvitationRequest.sharingInvitationUUIDKey <~~ json
        self.cloudFolderName = AddUserRequest.cloudFolderNameKey <~~ json

        if !nonNilKeysHaveValues(in: json) {
            return nil
        }
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
        return self.nonNilKeys() + [AddUserRequest.cloudFolderNameKey]
    }
    
    public func toJSON() -> JSON? {
        return jsonify([
            RedeemSharingInvitationRequest.sharingInvitationUUIDKey ~~> self.sharingInvitationUUID,
            AddUserRequest.cloudFolderNameKey ~~> self.cloudFolderName
        ])
    }
}

public class RedeemSharingInvitationResponse : ResponseMessage {
    // Present only as means to help clients uniquely identify users. This is *never* passed back to the server. This id is unique across all users and is not specific to any sign-in type (e.g., Google).
    public static let userIdKey = "userId"
    public var userId:UserId!
    
    public var sharingGroupUUID: String!
    
    public var responseType: ResponseType {
        return .json
    }
    
    public required init?(json: JSON) {
        userId = Decoder.decode(int64ForKey: RedeemSharingInvitationResponse.userIdKey)(json)
        sharingGroupUUID = ServerEndpoint.sharingGroupUUIDKey <~~ json
    }
    
    public convenience init?() {
        self.init(json:[:])
    }
    
    // MARK: - Serialization
    public func toJSON() -> JSON? {
        return jsonify([
            RedeemSharingInvitationResponse.userIdKey ~~> userId,
            ServerEndpoint.sharingGroupUUIDKey ~~> sharingGroupUUID
        ])
    }
}
