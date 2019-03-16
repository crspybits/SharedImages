//
//  RemoveUserFromSharingGroup.swift
//  SyncServer-Shared
//
//  Created by Christopher G Prince on 8/1/18.
//

import Foundation

public class RemoveUserFromSharingGroupRequest : RequestMessage, MasterVersionUpdateRequest {
    required public init() {}

    public var masterVersion: MasterVersionInt!
    private static let masterVersionKey = "masterVersion"
    
    public var sharingGroupUUID:String!

    public func valid() -> Bool {
        return sharingGroupUUID != nil && masterVersion != nil
    }
    
   private static func customConversions(dictionary: [String: Any]) -> [String: Any] {
        var result = dictionary
    
        // Unfortunate customization due to https://bugs.swift.org/browse/SR-5249
        MessageDecoder.convert(key: masterVersionKey, dictionary: &result) {MasterVersionInt($0)}
        return result
    }

    public static func decode(_ dictionary: [String: Any]) throws -> RequestMessage {
        return try MessageDecoder.decode(RemoveUserFromSharingGroupRequest.self, from: customConversions(dictionary: dictionary))
    }
}

public class RemoveUserFromSharingGroupResponse : ResponseMessage, MasterVersionUpdateResponse {
    required public init() {}

    public var masterVersionUpdate: MasterVersionInt?
    private static let masterVersionUpdateKey = "masterVersionUpdate"

    public var responseType: ResponseType {
        return .json
    }
    
    // Unfortunate customization due to https://bugs.swift.org/browse/SR-5249
    private static func customConversions(dictionary: [String: Any]) -> [String: Any] {
        var result = dictionary
        MessageDecoder.convert(key: masterVersionUpdateKey, dictionary: &result) {MasterVersionInt($0)}
        return result
    }
    
    public static func decode(_ dictionary: [String: Any]) throws -> RemoveUserFromSharingGroupResponse {
        return try MessageDecoder.decode(RemoveUserFromSharingGroupResponse.self, from: customConversions(dictionary: dictionary))
    }
}
