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
#if SERVER
    public required convenience init?(request: RouterRequest) {
        self.init(json: request.queryParameters)
    }
#endif
    
    public required init?(json: JSON) {
        super.init()
    }
    
    public func toJSON() -> JSON? {
        return jsonify([
        ])
    }
}

public class AddUserResponse : ResponseMessage {
    // Present only as means to help clients uniquely identify users. This is *never* passed back to the server. This id is unique across all users and is not specific to any sign-in type (e.g., Google).
    public static let userIdKey = "userId"
    public var userId:UserId!
    
    public var responseType: ResponseType {
        return .json
    }
    
    public required init?(json: JSON) {
        userId = Decoder.decode(int64ForKey: AddUserResponse.userIdKey)(json)
    }
    
    public convenience init?() {
        self.init(json:[:])
    }
    
    // MARK: - Serialization
    public func toJSON() -> JSON? {
        return jsonify([
            AddUserResponse.userIdKey ~~> userId
        ])
    }
}
