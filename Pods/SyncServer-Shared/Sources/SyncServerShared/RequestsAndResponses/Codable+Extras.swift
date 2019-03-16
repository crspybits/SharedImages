//
//  Codable+Extras.swift
//  SyncServer-Shared
//
//  Created by Christopher G Prince on 2/24/19.
//

import Foundation
#if SERVER
import LoggerAPI
#endif

class MessageEncoder {
    static func toDictionary<T>(encodable: T) -> [String: Any]? where T : Encodable {
        let encoder = JSONEncoder()
        let formatter = DateExtras.getDateFormatter(format: .DATETIME)
        encoder.dateEncodingStrategy = .formatted(formatter)
        guard let data = try? encoder.encode(encodable) else { return nil }
        return (try? JSONSerialization.jsonObject(with: data, options: .allowFragments)).flatMap { $0 as? [String: Any] }
    }
}

public class MessageDecoder {
    static func convert<T>(key: String, dictionary: inout [String: Any], fromString: (String) -> T?) {
        if let str = dictionary[key] as? String {
            dictionary[key] = fromString(str)
        }
    }
    
    // Because our toDictionary method, and I think because JSONSerialization.jsonObject, doesn't respect Bool's. i.e., they get converted to integer strings.
    static func convertBool(key: String, dictionary: inout [String: Any]) {
        if let str = dictionary[key] as? String {
            if let strBool = Bool(str) {
                dictionary[key] = strBool
            }
            else {
                switch str {
                case "1":
                    dictionary[key] = true
                case "0":
                    dictionary[key] = false
                default:
#if SERVER
                    Log.error("Error converting bool!")
#endif
                }
            }
        }
    }
    
    static func unescapeValues(dictionary: inout [String: Any]) {
        for (key, value) in dictionary {
            if let str = value as? String {
                dictionary[key] = str.unescape()
            }
        }
    }

    public static func decode<T>(_ type: T.Type, from json: Any) throws -> T where T: Decodable {
        let jsonData = try JSONSerialization.data(withJSONObject: json, options: [])
        let decoder = JSONDecoder()
        let formatter = DateExtras.getDateFormatter(format: .DATETIME)
        decoder.dateDecodingStrategy = .formatted(formatter)
        
        do {
            let result = try decoder.decode(type, from: jsonData)
            return result
        } catch (let error) {
            #if SERVER
                Log.error("Error decoding: \(error)")
            #endif
            throw error
        }
    }
}
