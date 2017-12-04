//
//  Assert.swift
//  WhatDidILike
//
//  Created by Christopher Prince on 10/2/14.
//  Copyright (c) 2014 Spastic Muffin, LLC. All rights reserved.
//

import Foundation

// See also http://stackoverflow.com/questions/24114288/macros-in-swift

open class Assert {
    // Must have upper case "I" in "If" here because "if" is a keyword.
    open class func If(_ conditionIsTrue: Bool, thenPrintThisString message: String) {
        #if DEBUG
            if conditionIsTrue {
                Log.error(message)
            }
            // For some reason, assert doesn't accept a string variable as a parameter; only a string constant.
            assert(!conditionIsTrue, "\(message)")
        #else
            if conditionIsTrue {
                Log.file(message)
            }
        #endif
    }
    
    open class func badMojo(alwaysPrintThisString message: String) {
        #if DEBUG
            Log.error(message)
            assert(false, "\(message)")
        #else
            Log.file(message)
        #endif
    }
}
