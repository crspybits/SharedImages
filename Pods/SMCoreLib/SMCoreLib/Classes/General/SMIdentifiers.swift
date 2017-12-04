//
//  SMIdentifiers.swift
//  Catsy
//
//  Created by Christopher Prince on 7/12/15.
//  Copyright (c) 2015 Spastic Muffin, LLC. All rights reserved.
//

// Common identifiers.

import Foundation

// @objc so we can access static properties from Objective-C.
@objc open class SMIdentifiers : NSObject {
    // You can make a subclass that assigns to this.
    open static var _session:SMIdentifiers?
    
    fileprivate static var appVersionString:String!
    fileprivate static var appBundleIdentifier:String!
    fileprivate static var appBuildString:String!

    // Exclusive property of SMShowingHints.swift
    open static let SHOWING_HINTS_FILE = "ShowingHints.dat"
    
    open static let SM_SUPPORT_EMAIL = "support@SpasticMuffin.biz"
    
    open static let LARGE_IMAGE_DIRECTORY = "largeImages"
    open static let SMALL_IMAGE_DIRECTORY = "smallImages"
    
    open class func session() -> SMIdentifiers {
        if self._session == nil {
            self._session = SMIdentifiers()
        }
        return self._session!
    }
    
    public override init() {
        super.init()
        SMIdentifiers.appVersionString = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as! String
        SMIdentifiers.appBundleIdentifier = Bundle.main.object(forInfoDictionaryKey: "CFBundleIdentifier") as! String
        SMIdentifiers.appBuildString = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as! String
    }
    
    open func APP_BUILD_STRING() -> String {
        return SMIdentifiers.appBuildString
    }
    
    open func APP_VERSION_FLOAT() -> Float {
        return (SMIdentifiers.appVersionString as NSString).floatValue
    }
    
    open func APP_VERSION_STRING() -> String {
        return SMIdentifiers.appVersionString
    }
    
    open func APP_BUNDLE_IDENTIFIER() -> String {
        return SMIdentifiers.appBundleIdentifier
    }
}
