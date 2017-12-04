//
//  NSError+Extras.swift
//  Catsy
//
//  Created by Christopher Prince on 9/19/15.
//  Copyright © 2015 Spastic Muffin, LLC. All rights reserved.
//

import Foundation

extension NSError {
    class func create(_ message:String) -> NSError {
        return NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey:message])
    }
    
    class func createWithCode(_ message:String, code:Int) -> NSError {
        return NSError(domain: "", code: code, userInfo: [NSLocalizedDescriptionKey:message])
    }
}
