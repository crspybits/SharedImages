//
//  SMDebug.swift
//  SMCommon
//
//  Created by Christopher Prince on 10/30/15.
//  Copyright © 2015 Spastic Muffin, LLC. All rights reserved.
//

import Foundation

@objc open class SMDebugInjectionTest : NSObject {
    open var injectTest:Bool = false
    
    public override init() {
        super.init()
        // TODO: Add these instances, when created, into a global set of injection test instances. And, grab those instances in the Debug Dashboard and present them to the debug user to enable the injection tests to be turned on or off.
    }

}

@objc open class SMDebug : NSObject {
    // public let exampleInjectionTest = SMDebugInjectionTest()
    
    open static let SMIAPReceiptInvalidReceipt = SMDebugInjectionTest()
    
    // My hope is that Swift will entirely compile out uses of these functions in production builds because their bodies will be empty.
    
    /* Usage:
    SMDebug.it {
        // Your debug code that will only execute for debug builds
    }
    */
    
    open class func it(_ yourDebugCode:()->()) {
        #if DEBUG
            yourDebugCode()
        #endif
    }
    
    /* Usage:
    SMDebug.injectTestIf(SMDebug.exampleInjectionTest) {
        // Your debug code that will only execute for debug builds, and when the injection test parameter injectTest property has the value true.
    }
    */
    
    open class func injectTestIf(_ condition:SMDebugInjectionTest, yourInjectionTest:()->()) {
        #if DEBUG
            if condition.injectTest {
                yourInjectionTest()
            }
        #endif
    }
}
