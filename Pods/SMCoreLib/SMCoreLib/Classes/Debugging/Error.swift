//
//  Error.swift
//  WhatDidILike
//
//  Created by Christopher Prince on 9/28/14.
//  Copyright (c) 2014 Spastic Muffin, LLC. All rights reserved.
//

import Foundation

open class SMError {
    open class func Create(_ message: String) -> NSError {
        return NSError(domain:"", code: 0, userInfo: [NSLocalizedDescriptionKey:message])
    }
}
