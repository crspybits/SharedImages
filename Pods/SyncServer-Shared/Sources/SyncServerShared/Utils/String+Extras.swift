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
#if SERVER
    public func toJSONDictionary() -> [String:Any]? {
        guard let data = self.data(using: String.Encoding.utf8) else {
            return nil
        }
        
        var json:Any?
        
        do {
            try json = JSONSerialization.jsonObject(with: data, options: JSONSerialization.ReadingOptions(rawValue: UInt(0)))
        } catch (let error) {
            Log.error(message: "Error in JSON conversion: \(error)")
            return nil
        }
        
        guard let jsonDict = json as? [String:Any] else {
            Log.error(message: "Could not convert json to json Dict")
            return nil
        }
        
        return jsonDict
    }
#endif

    public func escape() -> String? {
        return addingPercentEncoding(withAllowedCharacters: .urlHostAllowed)
    }
}
