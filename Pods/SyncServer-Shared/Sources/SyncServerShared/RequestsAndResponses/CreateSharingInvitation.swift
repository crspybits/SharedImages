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
    
    // For default values, see https://stackoverflow.com/questions/44575293/with-jsondecoder-in-swift-4-can-missing-keys-use-a-default-value-instead-of-hav
    
    private var _allowSocialAcceptance: Bool?
    private var _numberOfAcceptors:UInt?
    
    // Social acceptance means the inviting user allows hosting of accepting user's files.
    public var allowSocialAcceptance: Bool {
        get {
            if let social = _allowSocialAcceptance {
                return social
            }
            else {
                return true
            }
        }
        
        set {
            _allowSocialAcceptance = newValue
        }
    }
    
    // Number of people allowed to receive/accept invitation. >= 1
    public var numberOfAcceptors:UInt {
        get {
            if let number = _numberOfAcceptors {
                return number
            }
            else {
                return 1
            }
        }
        
        set {
            _numberOfAcceptors = newValue
        }
    }
    
    // The sharing group to which user(s) are being invited. The inviting user must have admin permissions in this group.
    public var sharingGroupUUID:String!
    
    private enum CodingKeys: String, CodingKey {
        case permission
        case _allowSocialAcceptance = "allowSocialAcceptance"
        case _numberOfAcceptors = "numberOfAcceptors"
        case sharingGroupUUID
    }
    
    public func valid() -> Bool {
        return sharingGroupUUID != nil && permission != nil && numberOfAcceptors >= 1
    }
    
    private static func customConversions(dictionary: [String: Any]) -> [String: Any] {
        var result = dictionary
        
        // Unfortunate customization due to https://bugs.swift.org/browse/SR-5249
        MessageDecoder.convertBool(key: CreateSharingInvitationRequest.CodingKeys._allowSocialAcceptance.rawValue, dictionary: &result)
        MessageDecoder.convert(key: CreateSharingInvitationRequest.CodingKeys._numberOfAcceptors.rawValue, dictionary: &result) {UInt($0)}
        return result
    }

    public static func decode(_ dictionary: [String: Any]) throws -> RequestMessage {
        return try MessageDecoder.decode(CreateSharingInvitationRequest.self, from: customConversions(dictionary: dictionary))
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
