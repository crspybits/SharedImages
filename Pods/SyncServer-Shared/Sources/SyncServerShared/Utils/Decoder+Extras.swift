//
//  Decoder+Extras.swift
//  Server
//
//  Created by Christopher Prince on 4/26/17.
//
//

import Foundation
import Gloss

// This extension is here because (a) the Kitura RouterRequest queryParameters property returns numbers as strings (i.e., quoted), and (b) Gloss doesn't interpret strings as numbers by default.

public extension Gloss.Decoder {
    // Attempt to convert a String to a mumber of type T
    private static func decodeStringAsNumber<T: Numeric>(json: JSON, toNumber:(String) -> T?, keyPath: String, keyPathDelimiter: String) -> T? {
    
        if let string = json.valueForKeyPath(keyPath: keyPath, withDelimiter: keyPathDelimiter) as? String {
            return toNumber(string)
        }
        
        return nil
    }
    
    public static func decode(int32ForKey key: String, keyPathDelimiter: String = GlossKeyPathDelimiter) -> (JSON) -> Int32? {
        return {
            json in
            
            if let number = json.valueForKeyPath(keyPath: key, withDelimiter: keyPathDelimiter) as? Int32 {
                return number
            }

            if let number = json.valueForKeyPath(keyPath: key, withDelimiter: keyPathDelimiter) as? Int {
                return Int32(number)
            }
            
            return decodeStringAsNumber(json: json, toNumber:{ Int32($0) }, keyPath: key, keyPathDelimiter: keyPathDelimiter)
        }
    }
    
    public static func decode(int64ForKey key: String, keyPathDelimiter: String = GlossKeyPathDelimiter) -> (JSON) -> Int64? {
        return {
            json in
            
            if let number = json.valueForKeyPath(keyPath: key, withDelimiter: keyPathDelimiter) as? Int64 {
                return number
            }
            
            if let number = json.valueForKeyPath(keyPath: key, withDelimiter: keyPathDelimiter) as? Int32 {
                return Int64(number)
            }
            
            if let number = json.valueForKeyPath(keyPath: key, withDelimiter: keyPathDelimiter) as? Int {
                return Int64(number)
            }
            
            return decodeStringAsNumber(json: json, toNumber:{ Int64($0) }, keyPath: key, keyPathDelimiter: keyPathDelimiter)
        }
    }
    
    public static func decode(floatForKey key: String, keyPathDelimiter: String = GlossKeyPathDelimiter) -> (JSON) -> Float? {
        return {
            json in
            
            if let number = json.valueForKeyPath(keyPath: key, withDelimiter: keyPathDelimiter) as? Float {
                return Float(number)
            }
            
            return decodeStringAsNumber(json: json, toNumber:{ Float($0) }, keyPath: key, keyPathDelimiter: keyPathDelimiter)
        }
    }
    
    public static func decode(doubleForKey key: String, keyPathDelimiter: String = GlossKeyPathDelimiter) -> (JSON) -> Double? {
        return {
            json in
            
            if let number = json.valueForKeyPath(keyPath: key, withDelimiter: keyPathDelimiter) as? Float {
                return Double(number)
            }
            
            if let number = json.valueForKeyPath(keyPath: key, withDelimiter: keyPathDelimiter) as? Double {
                return Double(number)
            }
            
            return decodeStringAsNumber(json: json, toNumber:{ Double($0) }, keyPath: key, keyPathDelimiter: keyPathDelimiter)
        }
    }
}

// This is here purely because I'm having problems calling these methods from the testing framework due to some odd name scoping issue.

#if TESTING
class TestSupport {
    public static func decode(int32ForKey key: String, keyPathDelimiter: String = GlossKeyPathDelimiter) -> (JSON) -> Int32? {
        return Decoder.decode(int32ForKey: key, keyPathDelimiter:keyPathDelimiter)
    }
    
    public static func decode(int64ForKey key: String, keyPathDelimiter: String = GlossKeyPathDelimiter) -> (JSON) -> Int64? {
        return Decoder.decode(int64ForKey: key, keyPathDelimiter:keyPathDelimiter)
    }
    
    public static func decode(floatForKey key: String, keyPathDelimiter: String = GlossKeyPathDelimiter) -> (JSON) -> Float? {
        return Decoder.decode(floatForKey: key, keyPathDelimiter:keyPathDelimiter)
    }
    
    public static func decode(doubleForKey key: String, keyPathDelimiter: String = GlossKeyPathDelimiter) -> (JSON) -> Double? {
        return Decoder.decode(doubleForKey: key, keyPathDelimiter:keyPathDelimiter)
    }
}
#endif
