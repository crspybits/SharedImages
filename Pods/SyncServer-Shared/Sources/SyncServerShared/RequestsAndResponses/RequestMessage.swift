//
//  RequestMessage.swift
//  Server
//
//  Created by Christopher Prince on 11/26/16.
//
//

import Foundation

#if SERVER
import Kitura
import LoggerAPI
#endif

public protocol RequestMessage : Codable {
    init()
    
    var toDictionary: [String: Any]? {get}

    func valid() -> Bool
    
#if SERVER
    func setup(request: RouterRequest) throws
#endif

    static func decode(_ dictionary: [String: Any]) throws -> RequestMessage
}

public extension RequestMessage {
#if SERVER
    public func setup(request: RouterRequest) throws {
    }
#endif

    public var toDictionary: [String: Any]? {
        return MessageEncoder.toDictionary(encodable: self)
    }

    public func urlParameters(dictionary: [String: Any]) -> String? {
        var result = ""
        // Sort the keys so I get the key=value pairs in a canonical form, for testing.
        for key in dictionary.keys.sorted() {
            if let keyValue = dictionary[key] {
                if result.count > 0 {
                    result += "&"
                }
                
                let newURLParameter = "\(key)=\(keyValue)"
                
                if let escapedNewKeyValue = newURLParameter.escape() {
                    result += escapedNewKeyValue
                }
                else {
#if SERVER
                    Log.error("Failed on escaping new key value: \(newURLParameter)")
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
    
    public func urlParameters() -> String? {
        guard let jsonDict = toDictionary else {
#if SERVER
            Log.error("Could not convert toJSON()!")
#endif
            return nil
        }
        
        return urlParameters(dictionary: jsonDict)
    }
}

