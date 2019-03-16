//
//  CreateSharingInvitation.swift
//  Server
//
//  Created by Christopher Prince on 4/9/17.
//
//

import Foundation

public class CreateSharingInvitationRequest : RequestMessage {
    required public init() {}

    public var permission:Permission!
    
    // The sharing group to which a user is being invited. The inviting user must have admin permissions in this group.
    public var sharingGroupUUID:String!
    
    public func valid() -> Bool {
        return sharingGroupUUID != nil && permission != nil
    }
    
    public static func decode(_ dictionary: [String: Any]) throws -> RequestMessage {
        return try MessageDecoder.decode(CreateSharingInvitationRequest.self, from: dictionary)
    }
}

public class CreateSharingInvitationResponse : ResponseMessage {
    required public init() {}

    public var sharingInvitationUUID:String!

    public var responseType: ResponseType {
        return .json
    }
    
    public static func decode(_ dictionary: [String: Any]) throws -> CreateSharingInvitationResponse {
        return try MessageDecoder.decode(CreateSharingInvitationResponse.self, from: dictionary)
    }
}
