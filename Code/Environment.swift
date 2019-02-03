//
//  Environment.swift
//  SharedImages
//
//  Created by Christopher G Prince on 11/12/17.
//  Copyright © 2017 Spastic Muffin, LLC. All rights reserved.
//

import Foundation
import PersistentValue

// System scoped parameters

enum EnvironmentServer : String {
    case production
    case staging
    case local
}

struct Environment {
    // static private var rawEnvironmentServer:SMPersistItemString = SMPersistItemString(name: "Environment.rawEnvironmentServer", initialStringValue: EnvironmentServer.production.rawValue, persistType: .userDefaults)
    static private var rawEnvironmentServer = try! PersistentValue<String>(name: "Environment.rawEnvironmentServer", storage: .file)
    
    static var current:EnvironmentServer {
        set {
            rawEnvironmentServer.value = newValue.rawValue
        }
        get {
            if rawEnvironmentServer.value == nil {
                return .production
            }
            else {
                return EnvironmentServer(rawValue: rawEnvironmentServer.value!)!
            }
        }
    }
    
    static func setup() {
        //current = .local
    }
}

