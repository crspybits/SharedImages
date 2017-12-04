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
    // This will be present iff the user is a sharing user. i.e., for an owning user it will be nil.
    public static let sharingPermissionKey = "sharingPermission"
    public var sharingPermission:SharingPermission!
    
    public var responseType: ResponseType {
        return .json
    }
    
    public required init?(json: JSON) {
        self.sharingPermission = Decoder.decodeSharingPermission(key: CheckCredsResponse.sharingPermissionKey, json: json)
    }
    
    public convenience init?() {
        self.init(json:[:])
    }
    
    // MARK: - Serialization
    public func toJSON() -> JSON? {
        return jsonify([
            Encoder.encodeSharingPermission(key: CheckCredsResponse.sharingPermissionKey, value: self.sharingPermission)
        ])
    }
}
