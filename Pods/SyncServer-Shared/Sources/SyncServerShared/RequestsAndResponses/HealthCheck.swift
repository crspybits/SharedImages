//
//  HealthCheck.swift
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

public class HealthCheckRequest : NSObject, RequestMessage {
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

public class HealthCheckResponse : ResponseMessage {
    public var responseType: ResponseType {
        return .json
    }
    
    public static let currentServerTimeKey = "currentServerDateTime"
    public var currentServerDateTime:Date!
    
    public static let serverUptimeKey = "serverUptime"
    public var serverUptime:TimeInterval!

    public static let deployedGitTagKey = "deployedGitTag"
    public var deployedGitTag:String!
    
    public static let diagnosticsKey = "diagnostics"
    public var diagnostics:String?

    public required init?(json: JSON) {
        serverUptime = Decoder.decode(doubleForKey: HealthCheckResponse.serverUptimeKey)(json)
        deployedGitTag = HealthCheckResponse.deployedGitTagKey <~~ json
        diagnostics = HealthCheckResponse.diagnosticsKey <~~ json
        
        let dateFormatter = DateExtras.getDateFormatter(format: .DATETIME)
        currentServerDateTime = Decoder.decode(dateForKey: HealthCheckResponse.currentServerTimeKey, dateFormatter: dateFormatter)(json)
    }
    
    public convenience init?() {
        self.init(json:[:])
    }
    
    // MARK: - Serialization
    public func toJSON() -> JSON? {
        let dateFormatter = DateExtras.getDateFormatter(format: .DATETIME)

        return jsonify([
            HealthCheckResponse.deployedGitTagKey ~~> deployedGitTag,
            HealthCheckResponse.diagnosticsKey ~~> diagnostics,
            HealthCheckResponse.serverUptimeKey ~~> serverUptime,
            Encoder.encode(dateForKey: HealthCheckResponse.currentServerTimeKey, dateFormatter: dateFormatter)(currentServerDateTime)
        ])
    }
}
