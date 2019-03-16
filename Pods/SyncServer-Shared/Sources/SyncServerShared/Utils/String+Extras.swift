//
//  String+Extras.swift
//  Server
//
//  Created by Christopher Prince on 2/12/17.
//
//

import Foundation
#if SERVER
import PerfectLib
#endif

extension String {
    public func toJSONDictionary() -> [String:Any]? {
        guard let data = self.data(using: String.Encoding.utf8) else {
            return nil
        }
        
        var json:Any?
        
        // return (try? JSONSerialization.jsonObject(with: data, options: .allowFragments)).flatMap { $0 as? [String: Any] }
        
        do {
            try json = JSONSerialization.jsonObject(with: data, options: JSONSerialization.ReadingOptions(rawValue: UInt(0)))
        } catch (let error) {
            #if SERVER
                Log.error(message: "Error in JSON conversion: \(error); self: \(self)")
            #endif
            return nil
        }
        
        guard let jsonDict = json as? [String:Any] else {
            #if SERVER
                Log.error(message: "Could not convert json to json Dict")
            #endif
            return nil
        }
        
        return jsonDict
    }

    public func escape() -> String? {
        return addingPercentEncoding(withAllowedCharacters: .urlHostAllowed)
    }
    
    public func unescape() -> String? {
        return removingPercentEncoding
    }    
}
