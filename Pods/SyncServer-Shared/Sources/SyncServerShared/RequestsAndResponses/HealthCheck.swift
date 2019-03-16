//
//  HealthCheck.swift
//  Server
//
//  Created by Christopher Prince on 11/26/16.
//
//

import Foundation

public class HealthCheckRequest : RequestMessage {
    required public init() {}

    public func valid() -> Bool {
        return true
    }
    
    public static func decode(_ dictionary: [String: Any]) throws -> RequestMessage {
        return try MessageDecoder.decode(HealthCheckRequest.self, from: dictionary)
    }
}

public class HealthCheckResponse : ResponseMessage {
    required public init() {}

    public var responseType: ResponseType {
        return .json
    }
    
    public var currentServerDateTime:Date!
    public var serverUptime:TimeInterval!
    public var deployedGitTag:String!
    public var diagnostics:String?

    public static func decode(_ dictionary: [String: Any]) throws -> HealthCheckResponse {
        return try MessageDecoder.decode(HealthCheckResponse.self, from: dictionary)
    }
}
