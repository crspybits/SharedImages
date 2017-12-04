//
//  SMLazyWeakRef.swift
//  SMCoreLib
//
//  Created by Christopher Prince on 6/11/16.
//  Copyright © 2016 Spastic Muffin, LLC. All rights reserved.
//

import Foundation

// Similar to the WeakRef type, but with stronger typing and a callback that gets called just before the getter returns the value-- to provide a new value.

open class SMLazyWeakRef<T: AnyObject> {
    fileprivate weak var _lazyRef:T?
    
    open weak var lazyRef:T? {
        self._lazyRef = self.willGetCallback()
        return self._lazyRef
    }
    
    fileprivate var willGetCallback:(()->(T?))
    
    public init(willGetCallback:@escaping (()->(T?))) {
        self.willGetCallback = willGetCallback
    }
}
