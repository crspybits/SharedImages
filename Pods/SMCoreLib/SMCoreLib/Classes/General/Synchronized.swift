//
//  Synchronized.swift
//  Catsy
//
//  Created by Christopher Prince on 6/13/15.
//  Copyright (c) 2015 Spastic Muffin, LLC. All rights reserved.
//

import Foundation

// From http://stackoverflow.com/questions/24045895/what-is-the-swift-equivalent-to-objective-cs-synchronized

open class Synchronized {
    open class func block(_ lock: AnyObject, closure: () -> ()) {
        objc_sync_enter(lock)
        closure()
        objc_sync_exit(lock)
    }
}
