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

public extension RequestMessage {
    public func allKeys() -> [String] {
        return []
    }

    public func nonNilKeys() -> [String] {
        return []
    }
    
    // Lots of problems trying to use reflection to do this. This is simpler. See also http://stackoverflow.com/questions/43794228/getting-the-value-of-a-property-using-its-string-name-in-pure-swift-using-refle
    func nonNilKeysHaveValues(in dictionary: [String: Any]) -> Bool {
        for key in self.nonNilKeys() {
            if dictionary[key] == nil {
#if SERVER
                Log.error(message: "Key '\(key)' did not have value!")
#endif
                return false
            }
        }
        return true
    }
    
    public func urlParameters() -> String? {
        // 6/9/17; I was previously using reflection to do this, and not just converting to a dict. Can't recall why. However, this started giving me grief when I started using dates.
        guard let jsonDict = toJSON() else {
#if SERVER
            Log.error(message: "Could not convert toJSON()!")
#endif
            return nil
        }
        
        var result = ""
        for key in self.allKeys() {
            if let keyValue = jsonDict[key] {
                if result.count > 0 {
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
        
        if result.count == 0 {
            return nil
        }
        else {
            return result
        }
    }
}

