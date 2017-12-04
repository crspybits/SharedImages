//
//  SMRelativeLocalURL.swift
//  SMCoreLib
//
//  Created by Christopher Prince on 3/21/16.
//  Copyright © 2016 Spastic Muffin, LLC. All rights reserved.
//

import Foundation

//  NSURL subclass to deal with relative local URL's.

open class SMRelativeLocalURL : NSURL {
    // Need the @objc prefix to use the init method below, that has this type as a parameter, from Objective-C.
    @objc public enum BaseURLType : Int {
        case documentsDirectory
        case mainBundle
        case nonLocal
    }
    
    fileprivate var _localBaseURLType:BaseURLType = .nonLocal
    
    // The file is assumed to be stored in the Documents directory of the app. Upon decoding, the URL is reconsituted based on this assumption. This is because the location of the app in the file system can change with re-installation. See http://stackoverflow.com/questions/9608971/app-updates-nsurl-and-documents-directory

    fileprivate class var documentsURL: URL {
        get {
            let urls = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
            let documentsURL = urls[0]
            return documentsURL
        }
    }
    
    fileprivate class var mainBundleURL: URL {
        get {
            return Bundle.main.bundleURL
        }
    }
    
    // To create a non-local non-relative URL.
    public override init(fileURLWithPath: String) {
        super.init(fileURLWithPath: fileURLWithPath)
    }
    
    // The localBaseType cannot be .NonLocal. Use a fileURLWithPath constructor if you need a non-relative/non-local NSURL.
    public init?(withRelativePath relativePath:String, toBaseURLType localBaseType:BaseURLType) {
        var baseURL:URL

        switch localBaseType {
        case .mainBundle:
            baseURL = SMRelativeLocalURL.mainBundleURL

        case .documentsDirectory:
            baseURL = SMRelativeLocalURL.documentsURL
            
        case .nonLocal:
            Assert.badMojo(alwaysPrintThisString: "Should not use this for NonLocal")
            baseURL = URL(string: "")!
        }
        
        // This constructor notation is a little odd. "relativeToURL" is the part of the URL on the left.
        super.init(string: relativePath, relativeTo: baseURL)
        
        self._localBaseURLType = localBaseType
    }

    required public init?(coder aDecoder: NSCoder) {
        let rawValue = aDecoder.decodeInteger(forKey: "localBaseURLType") 
        self._localBaseURLType = BaseURLType(rawValue: rawValue)!
        
        let relativePath = aDecoder.decodeObject(forKey: "relativePath") as! String
        
        switch self._localBaseURLType {
        case .mainBundle:
            super.init(string: relativePath, relativeTo: SMRelativeLocalURL.mainBundleURL)

        case .documentsDirectory:
            super.init(string: relativePath, relativeTo: SMRelativeLocalURL.documentsURL)
            
        case .nonLocal:
            super.init(coder: aDecoder)
        }
    }
    
    // TODO: See what it will take to make this support secure coding. See Apple's Secure Coding Guide
    open override static var supportsSecureCoding : Bool {
        return false
    }
    
    open override func encode(with aCoder: NSCoder) {
        super.encode(with: aCoder)
        _ = self._localBaseURLType.rawValue
        aCoder.encode(self._localBaseURLType.rawValue, forKey: "localBaseURLType")
        aCoder.encode(self.relativePath, forKey: "relativePath")
    }

    required convenience public init(fileReferenceLiteral path: String) {
        fatalError("init(fileReferenceLiteral:) has not been implemented")
    }
    
    required public init(itemProviderData data: Data, typeIdentifier: String) throws {
        fatalError("init(itemProviderData:typeIdentifier:) has not been implemented")
    }
}
