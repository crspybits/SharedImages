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

    // This must be present when redeeming an invitation: a) using an owning account, b) that owning account type needs a cloud storage folder (e.g., Google Drive), and c) with permissions of >= write.
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
    
    public var sharingGroupId: SharingGroupId!
    
    public var responseType: ResponseType {
        return .json
    }
    
    public required init?(json: JSON) {
        userId = Decoder.decode(int64ForKey: RedeemSharingInvitationResponse.userIdKey)(json)
        sharingGroupId = Decoder.decode(int64ForKey: ServerEndpoint.sharingGroupIdKey)(json)
    }
    
    public convenience init?() {
        self.init(json:[:])
    }
    
    // MARK: - Serialization
    public func toJSON() -> JSON? {
        return jsonify([
            RedeemSharingInvitationResponse.userIdKey ~~> userId,
            ServerEndpoint.sharingGroupIdKey ~~> sharingGroupId
        ])
    }
}
