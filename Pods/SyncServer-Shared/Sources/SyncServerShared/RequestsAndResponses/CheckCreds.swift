//
//  CheckCreds.swift
//  Server
//
//  Created by Christopher Prince on 11/26/16.
//
//

import Foundation

// Check to see if both primary and secondary authentication succeed. i.e., check to see if a user exists.

public class CheckCredsRequest : RequestMessage {
    required public init() {}

    public func valid() -> Bool {
        return true
    }
    
    public static func decode(_ dictionary: [String: Any]) throws -> RequestMessage {
        return try MessageDecoder.decode(CheckCredsRequest.self, from: dictionary)
    }
}

public class CheckCredsResponse : ResponseMessage {
    required public init() {}

    // Present only as means to help clients uniquely identify users. This is *never* passed back to the server. This id is unique across all users and is not specific to any sign-in type (e.g., Google).
    public var userId:UserId!
    private static let userIdKey = "userId"

    public var responseType: ResponseType {
        return .json
    }
    
    private static func customConversions(dictionary: [String: Any]) -> [String: Any] {
        var result = dictionary
        
        // Unfortunate customization due to https://bugs.swift.org/browse/SR-5249
        MessageDecoder.convert(key: userIdKey, dictionary: &result) {UserId($0)}
        
        return result
    }

    public static func decode(_ dictionary: [String: Any]) throws -> CheckCredsResponse {
        return try MessageDecoder.decode(CheckCredsResponse.self, from: customConversions(dictionary: dictionary))
    }
}
