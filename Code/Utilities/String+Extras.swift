//
//  String+Extras.swift
//  SharedImages
//
//  Created by Christopher G Prince on 4/30/19.
//  Copyright © 2019 Spastic Muffin, LLC. All rights reserved.
//

import Foundation

extension String {
    static func dictToJSONString(_ dict: [String: Any]) -> String? {
        guard let data = try? JSONSerialization.data(withJSONObject: dict, options: JSONSerialization.WritingOptions(rawValue: 0)) else {
            return nil
        }
        
        guard let jsonString = String(data: data, encoding: String.Encoding.utf8) else {
            return nil
        }
        
        return jsonString
    }
    
    func jsonStringToDict() -> [String: Any]? {
        if let jsonData = self.data(using: String.Encoding.utf8, allowLossyConversion: false) {
        
            if let json = try? JSONSerialization.jsonObject(with: jsonData, options: []) as? [String: Any] {
                return json
            }
        }
        
        return nil
    }
}
