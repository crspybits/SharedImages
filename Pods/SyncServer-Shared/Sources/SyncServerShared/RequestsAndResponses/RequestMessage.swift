//
//  RequestMessage.swift
//  Server
//
//  Created by Christopher Prince on 11/26/16.
//
//

import Foundation
import Gloss

#if SERVER
import PerfectLib
import Kitura
#endif

public protocol RequestMessage : NSObjectProtocol, Gloss.Encodable, Gloss.Decodable {
    init?(json: JSON)
    
#if SERVER
    init?(request: RouterRequest)
#endif

    func allKeys() -> [String]
    func nonNilKeys() -> [String]
}

// See http://stackoverflow.com/questions/43794228/getting-the-value-of-a-property-using-its-string-name-in-pure-swift-using-refle
// Don't pass this an unwrapped optional. i.e., unwrap an optional before you pass it.
public func valueFor(property:String, of object:Any) -> Any? {
    func isNilDescendant(_ any: Any?) -> Bool {
        return String(describing: any) == "Optional(nil)"
    }
    
    let mirror = Mirror(reflecting: object)
    if let child = mirror.descendant(property), !isNilDescendant(child) {
        return child
    }
    else {
        return nil
    }
}

public extension RequestMessage {
    public func allKeys() -> [String] {
        return []
    }

    public func nonNilKeys() -> [String] {
        return []
    }
    
    // http://stackoverflow.com/questions/27989094/how-to-unwrap-an-optional-value-from-any-type/43754449#43754449
    private func unwrap<T>(_ any: T) -> Any {
        let mirror = Mirror(reflecting: any)
        guard mirror.displayStyle == .optional, let first = mirror.children.first else {
            return any
        }
        return unwrap(first.value)
    }
    
    public func urlParameters() -> String? {
        // 6/9/17; I was previously using `valueFor` method, and not just converting to a dict. Can't recall why. However, this started giving me grief when I started using dates.
        guard let jsonDict = toJSON() else {
#if SERVER
            Log.error(message: "Could not convert toJSON()!")
#endif
            return nil
        }
        
        var result = ""
        for key in self.allKeys() {
            if let keyValue = jsonDict[key] {
                if result.characters.count > 0 {
                    result += "&"
                }
                
                let newURLParameter = "\(key)=\(keyValue)"
                
                if let escapedNewKeyValue = newURLParameter.escape() {
                    result += escapedNewKeyValue
                }
                else {
#if SERVER
                    Log.critical(message: "Failed on escaping new key value!")
#endif
#if DEBUG
                    assert(false)
#endif
                }
            }
        }
        
        if result.characters.count == 0 {
            return nil
        }
        else {
            return result
        }
    }
    
    public func propertyHasValue(propertyName:String) -> Bool {
        if valueFor(property: propertyName, of: self) == nil {
            return false
        }
        else {
            return true
        }
    }
    
    // Returns false if any of the properties do not have value.
    public func propertiesHaveValues(propertyNames:[String]) -> Bool {
        for propertyName in propertyNames {
            if !self.propertyHasValue(propertyName: propertyName) {
                let message = "Property: \(propertyName) does not have a value"
#if SERVER
                Log.info(message: message)
#else
                print(message)
#endif
                return false
            }
        }
        
        return true
    }
}

