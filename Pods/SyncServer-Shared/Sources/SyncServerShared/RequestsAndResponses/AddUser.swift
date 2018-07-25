//
//  AddUser.swift
//  Server
//
//  Created by Christopher Prince on 11/26/16.
//
//

import Foundation
import Gloss

#if SERVER
import Kitura
#endif

public class AddUserRequest : NSObject, RequestMessage {
    // A root-level folder in the cloud file service. This is only used by some of the cloud file servces. E.g., Google Drive. It's not used by Dropbox.
    public static let cloudFolderNameKey = "cloudFolderName"
    public var cloudFolderName:String?
    public static let maxCloudFolderNameLength = 256
    
#if SERVER
    public required convenience init?(request: RouterRequest) {
        self.init(json: request.queryParameters)
    }
#endif
    
    public required init?(json: JSON) {
        super.init()
        
        self.cloudFolderName = AddUserRequest.cloudFolderNameKey <~~ json
    }
    
    public func toJSON() -> JSON? {
        return jsonify([
            AddUserRequest.cloudFolderNameKey ~~> self.cloudFolderName
        ])
    }
    
    public func allKeys() -> [String] {
        return [AddUserRequest.cloudFolderNameKey]
    }
}

public class AddUserResponse : ResponseMessage {
    // Present only as means to help clients uniquely identify users. This is *never* passed back to the server. This id is unique across all users and is not specific to any sign-in type (e.g., Google).
    public static let userIdKey = "userId"
    public var userId:UserId!
    
    public var sharingGroupId: SharingGroupId!
    
    public var responseType: ResponseType {
        return .json
    }
    
    public required init?(json: JSON) {
        userId = Decoder.decode(int64ForKey: AddUserResponse.userIdKey)(json)
        sharingGroupId = Decoder.decode(int64ForKey: ServerEndpoint.sharingGroupIdKey)(json)
    }
    
    public convenience init?() {
        self.init(json:[:])
    }
    
    // MARK: - Serialization
    public func toJSON() -> JSON? {
        return jsonify([
            AddUserResponse.userIdKey ~~> userId,
            ServerEndpoint.sharingGroupIdKey ~~> sharingGroupId
        ])
    }
}
