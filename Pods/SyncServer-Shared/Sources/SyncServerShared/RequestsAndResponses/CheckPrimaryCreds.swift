//
//  CheckPrimaryCreds.swift
//  Server
//
//  Created by Christopher Prince on 12/17/16.
//
//

import Foundation
import Gloss

#if SERVER
import Kitura
#endif

public class CheckPrimaryCredsRequest : NSObject, RequestMessage {
#if SERVER
    public required convenience init?(request: RouterRequest) {
        self.init(json: request.queryParameters)
    }
#endif
    
    public required init?(json: JSON) {
        super.init()
        
        if !nonNilKeysHaveValues(in: json) {
            return nil
        }
    }
    
    public func toJSON() -> JSON? {
        return jsonify([
        ])
    }
}

public class CheckPrimaryCredsResponse : ResponseMessage {
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
