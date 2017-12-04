//
//  JSONExtras.swift
//  Server
//
//  Created by Christopher Prince on 7/18/17.
//

import Foundation

public class JSONExtras {
    public static func toJSONString(dict:[String:Any]) -> String? {
        var data:Data!
        
        do {
            try data = JSONSerialization.data(withJSONObject: dict, options: JSONSerialization.WritingOptions(rawValue: UInt(0)))
        } catch {
            return nil
        }
        
        return String(data: data, encoding: String.Encoding.utf8)
    }
}
