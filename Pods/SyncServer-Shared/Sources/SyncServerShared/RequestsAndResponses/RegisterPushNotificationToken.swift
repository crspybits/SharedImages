//
//  RegisterPushNotificationToken.swift
//  SyncServer-Shared
//
//  Created by Christopher G Prince on 2/6/19.
//

import Foundation

// Enable an app to register a Push Notification token.

public class RegisterPushNotificationTokenRequest : RequestMessage {
    required public init() {}

    public var pushNotificationToken: String!
    
    public func valid() -> Bool {
        guard pushNotificationToken != nil else {
            return false
        }
        
        return true
    }
    
    public static func decode(_ dictionary: [String: Any]) throws -> RequestMessage {
        return try MessageDecoder.decode(RegisterPushNotificationTokenRequest.self, from: dictionary)
    }
}

public class RegisterPushNotificationTokenResponse : ResponseMessage {
    required public init() {}

    public var responseType: ResponseType {
        return .json
    }
    
    public static func decode(_ dictionary: [String: Any]) throws -> RegisterPushNotificationTokenResponse {
        return try MessageDecoder.decode(RegisterPushNotificationTokenResponse.self, from: dictionary)
    }
}
