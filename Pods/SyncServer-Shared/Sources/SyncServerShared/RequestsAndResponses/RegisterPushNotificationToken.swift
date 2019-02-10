//
//  RegisterPushNotificationToken.swift
//  SyncServer-Shared
//
//  Created by Christopher G Prince on 2/6/19.
//

import Foundation
import Gloss

#if SERVER
import Kitura
#endif

// Enable an app to register a Push Notification token.

public class RegisterPushNotificationTokenRequest : NSObject, RequestMessage {
    public static let pushNotificationTokenKey = "pushNotificationToken"
    public var pushNotificationToken: String!
    
    public func nonNilKeys() -> [String] {
        return [RegisterPushNotificationTokenRequest.pushNotificationTokenKey]
    }
    
    public func allKeys() -> [String] {
        var keys = [String]()
        keys += self.nonNilKeys()

        return keys
    }
    
    public required init?(json: JSON) {
        super.init()
        
        self.pushNotificationToken = RegisterPushNotificationTokenRequest.pushNotificationTokenKey <~~ json
        
        if !nonNilKeysHaveValues(in: json) {
            return nil
        }
    }
    
#if SERVER
    public required convenience init?(request: RouterRequest) {
        self.init(json: request.queryParameters)
    }
#endif
    
    public func toJSON() -> JSON? {
        var param:[JSON?] = []
        
        param += [RegisterPushNotificationTokenRequest.pushNotificationTokenKey ~~> self.pushNotificationToken]

        return jsonify(param)
    }
}

public class RegisterPushNotificationTokenResponse : ResponseMessage {
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
