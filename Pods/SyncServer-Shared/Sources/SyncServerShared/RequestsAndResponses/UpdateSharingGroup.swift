//
//  UpdateSharingGroup.swift
//  SyncServer-Shared
//
//  Created by Christopher G Prince on 8/4/18.
//

import Foundation

public class UpdateSharingGroupRequest : RequestMessage, MasterVersionUpdateRequest {
    required public init() {}

    public var masterVersion:MasterVersionInt!
    private static let masterVersionKey = "masterVersion"
    
    // I'm having problems uploading complex objects in url parameters. So not sending a SharingGroup object yet. If I need to do this, looks like I'll have to use the request body and am not doing that yet.
    public var sharingGroupUUID:String!
    
    public var sharingGroupName: String?

    public func valid() -> Bool {
        return sharingGroupUUID != nil && sharingGroupName != nil && masterVersion != nil
    }
    
   private static func customConversions(dictionary: [String: Any]) -> [String: Any] {
        var result = dictionary
    
        // Unfortunate customization due to https://bugs.swift.org/browse/SR-5249
        MessageDecoder.convert(key: masterVersionKey, dictionary: &result) {MasterVersionInt($0)}
        return result
    }

    public static func decode(_ dictionary: [String: Any]) throws -> RequestMessage {
        return try MessageDecoder.decode(UpdateSharingGroupRequest.self, from: customConversions(dictionary: dictionary))
    }
}

public class UpdateSharingGroupResponse : ResponseMessage, MasterVersionUpdateResponse {
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
    
    public static func decode(_ dictionary: [String: Any]) throws -> UpdateSharingGroupResponse {
        return try MessageDecoder.decode(UpdateSharingGroupResponse.self, from: customConversions(dictionary: dictionary))
    }
}
