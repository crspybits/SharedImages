//
//  RosterDevInjectTest.swift
//  roster
//
//  Created by Christopher G Prince on 8/9/17.
//  Copyright © 2017 roster. All rights reserved.
//

import Foundation

public class RosterDevInjectTest {
    static var runTestsMultipleTimes: Bool {
        set {
            RosterDevInjectTestObjC.session().runTestsMultipleTimes = newValue
        }
        
        get {
            return RosterDevInjectTestObjC.session().runTestsMultipleTimes
        }
    }
    
    static var sortedTestCaseNames: [String] {
        return RosterDevInjectTestObjC.session().sortedTestCaseNames
    }
    
    private init() {
    }
    
    static func reset() {
        RosterDevInjectTestObjC.session().reset()
    }
    
    // Returns `testCaseName` as a convenience.
    public static func define(testCaseName: String) -> String {
        RosterDevInjectTestObjC.session().defineTest(testCaseName)
        return testCaseName
    }

    static func set(testCaseName: String, value: Bool) {
        RosterDevInjectTestObjC.session().setTest(testCaseName, valueTo: value)
    }
    
    static func testIsOn(_ testCaseName: String) -> Bool {
        return RosterDevInjectTestObjC.session().testIs(on: testCaseName)
    }

    public static func `if`(_ testCaseName:String, callback:@escaping ()->()) {
        RosterDevInjectTestObjC.session().swiftRun(testCaseName) {
            callback()
        }
    }
}
