//
//  RemoveUser.swift
//  Server
//
//  Created by Christopher Prince on 12/23/16.
//
//

import Foundation
import Gloss

#if SERVER
import Kitura
#endif

public class RemoveUserRequest : NSObject, RequestMessage {
    // No specific user info is required here because the HTTP auth headers are used to identify the user to be removed. i.e., for now a user can only remove themselves.
    public required init?(json: JSON) {
        super.init()
    }
    
#if SERVER
    public required convenience init?(request: RouterRequest) {
        self.init(json: request.queryParameters)
    }
#endif
    
    public func toJSON() -> JSON? {
        return jsonify([
        ])
    }
}

public class RemoveUserResponse : ResponseMessage {
    public var responseType: ResponseType {
        return .json
    }
    
    public required init?(json: JSON) {
    }
    
    public convenience init?() {
        self.init(json:[:])
    }
    
    // MARK: - Serialization
    public func toJSON() -> JSON? {
        return jsonify([
        ])
    }
}
