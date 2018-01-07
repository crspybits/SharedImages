//
//  TestCases.swift
//  roster
//
//  Created by Christopher G Prince on 1/7/18.
//  Copyright © 2017 Spastic Muffin, LLC. All rights reserved.
//

import Foundation
import rosterdev

class TestCases {
    private init() {
    }
    
    static let session = TestCases()
    
    static func setup() {
        _ = session
    }
    
    // Make these text names fairly short. They are presented in a UI.
    
    let testCrashNextUpload = RosterDevInjectTest.define(testCaseName: "CrashNextUpload")
    let testCrashNextDownload = RosterDevInjectTest.define(testCaseName: "CrashNextDownload")
}
