//
//  Environment.swift
//  SharedImages
//
//  Created by Christopher G Prince on 11/12/17.
//  Copyright © 2017 Spastic Muffin, LLC. All rights reserved.
//

import Foundation
import SMCoreLib

// System scoped parameters

enum EnvironmentServer : String {
    case production
    case staging
    case local
}

struct Environment {
    static private var rawEnvironmentServer:SMPersistItemString = SMPersistItemString(name: "Environment.rawEnvironmentServer", initialStringValue: EnvironmentServer.production.rawValue, persistType: .userDefaults)
    
    static var current:EnvironmentServer {
        set {
            rawEnvironmentServer.stringValue = newValue.rawValue
        }
        get {
            return EnvironmentServer(rawValue: rawEnvironmentServer.stringValue)!
        }
    }
    
    static func setup() {
        // current = .local
    }
}

