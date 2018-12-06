//
//  PersistentValue.swift
//
//  Created by Christopher G Prince on 7/26/17.
//  Copyright © 2017 roster. All rights reserved.
//

import SwiftyUserDefaults
import KeychainAccess
import Foundation

public enum PersistentValueStorage {
    case userDefaults
    case keyChain
}

public class PersistentValue<T> {
    // Previously, this string was the same across some variants of the app I was building -- however, this generated a problem -- it caused sharing of keychain values across the app store and beta apps! See also https://stackoverflow.com/questions/47272209/sharing-of-keychain-values-across-apps-with-similar-bundle-ids
    private let keychainService = Bundle.main.bundleIdentifier!
    
    enum KeyValueError : Error {
        case unsupportedGenericType
    }

    private let itemType:KeyValueItem
    private let storage: PersistentValueStorage
    private let name:String
    
    enum KeyValueItem {
        case string
        case int
        case bool
        case data
    }
    
    public init(name: String, storage: PersistentValueStorage) throws {
        self.storage = storage
        self.name = name
                
        switch T.self {
        case is String.Type:
            itemType = .string
        case is Int.Type:
            itemType = .int
        case is Bool.Type:
            itemType = .bool
        case is Data.Type:
            itemType = .data
        default:
            throw KeyValueError.unsupportedGenericType
        }
    }
    
    public var value:T {
        set {
            switch storage {
                case .userDefaults:
                    switch itemType {
                    case .string:
                        UserDefaults.standard.setValue(newValue as! String, forKey: name)
                    case .int:
                        UserDefaults.standard.set(newValue, forKey: name)
                    case .bool:
                        UserDefaults.standard.set(newValue, forKey: name)
                    case .data:
                        UserDefaults.standard.set(newValue, forKey: name)
                    }
                    UserDefaults.standard.synchronize()
                
                case .keyChain:
                    let keychain = Keychain(service: keychainService)

                    switch itemType {
                    case .string:
                        keychain[name] = (newValue as! String)

                    case .int:
                        var value = newValue
                        let data = Data(bytes: &value, count: MemoryLayout<Int>.size)
                        keychain[data: name] = data
                    
                    case .bool:
                        var boolAsInt: Int = (newValue as! Bool) ? 1 : 0
                        let data = Data(bytes: &boolAsInt, count: MemoryLayout<Int>.size)
                        keychain[data: name] = data
                        
                    case .data:
                        keychain[data: name] = (newValue as! Data)
                    }
            }
        }
        
        get {
            switch storage {
                case .userDefaults:
                    switch itemType {
                    case .string:
                        return Defaults[name].stringValue as! T
                    case .int:
                        return Defaults[name].intValue as! T
                    case .bool:
                        return Defaults[name].boolValue as! T
                    case .data:
                        return Defaults[name].dataValue as! T
                    }
                
                case .keyChain:
                    let keychain = Keychain(service: keychainService)

                    switch itemType {
                    case .string:
                        if let result = keychain[name] as? T {
                            return result
                        }
                        else {
                            return "" as! T
                        }
                        
                    case .int:
                        if let data = keychain[data: name] {
                            let result = getInt(fromData: data, start: 0)
                            return result as! T
                        }
                        else {
                            return 0 as! T
                        }
                    case .bool:
                        if let data = keychain[data: name] {
                            let result = getInt(fromData: data, start: 0)
                            return (result == 1) as! T
                        }
                        else {
                            return false as! T
                        }
                    case .data:
                        if let result = keychain[data: name] as? T {
                            return result
                        }
                        else {
                            return Data() as! T
                        }
                    } // end switch itemType
            } // end switch storage
        }
    }
    
    // From https://stackoverflow.com/questions/26227702/converting-nsdata-to-integer-in-swift
    private func getInt(fromData data: Data, start: Int) -> Int {
        let intBits = data.withUnsafeBytes({(bytePointer: UnsafePointer<UInt8>) -> Int in
            bytePointer.advanced(by: start).withMemoryRebound(to: Int.self, capacity: 4) { pointer in
                return pointer.pointee
            }
        })
        return Int(littleEndian: intBits)
    }
}

