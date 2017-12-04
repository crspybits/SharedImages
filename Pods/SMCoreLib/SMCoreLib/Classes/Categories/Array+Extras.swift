//
//  Array+Extras.swift
//  SMCoreLib
//
//  Created by Christopher Prince on 5/20/16.
//  Copyright © 2016 Spastic Muffin, LLC. All rights reserved.
//

import Foundation

public extension Array {
    // Returns an array consisting of all but the first element. Returns empty array if there are no elements in tail, or if array was empty to be begin with.
    public func tail() -> Array {
        if self.count > 0 {
            return Array(self[1..<self.count])
        }
        else {
            return Array<Element>()
        }
    }
}