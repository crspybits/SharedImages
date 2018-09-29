//
//  CheckCreds.swift
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

// Check to see if both primary and secondary authentication succeed. i.e., check to see if a user exists.

public class CheckCredsRequest : NSObject, RequestMessage {
    public required init?(json: JSON) {
        super.init()
        
        if !nonNilKeysHaveValues(in: json) {
            return nil
        }
    }
    
#if SERVER
    public required init?(request: RouterRequest) {
        super.init()
    }
#endif

    public func toJSON() -> JSON? {
        return jsonify([
        ])
    }
}

public class CheckCredsResponse : ResponseMessage {
    // Present only as means to help clients uniquely identify users. This is *never* passed back to the server. This id is unique across all users and is not specific to any sign-in type (e.g., Google).
    public static let userIdKey = "userId"
    public var userId:UserId!
    
    public var responseType: ResponseType {
        return .json
    }
    
    public required init?(json: JSON) {
        userId = Decoder.decode(int64ForKey: CheckCredsResponse.userIdKey)(json)
    }
    
    public convenience init?() {
        self.init(json:[:])
    }
    
    // MARK: - Serialization
    public func toJSON() -> JSON? {
        return jsonify([
            CheckCredsResponse.userIdKey ~~> userId,
        ])
    }
}
