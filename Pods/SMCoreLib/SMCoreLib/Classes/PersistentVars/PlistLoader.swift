//
//  PlistLoader.swift
//  Pods
//
//  Created by Christopher Prince on 12/26/16.
//
//

import Foundation

open class PlistDictLoader {
    
    public enum PlistDictLoaderError : Error {
    case fileNotFound(name:String)
    case requiredVarNotFound(key:String)
    case requiredStringVarNotFound(key:String)
    case requiredIntVarNotFound(key:String)
    }
    
    private let plistDict:NSDictionary!
    
    // Filename must have the .plist extension.
    // throws an error if the plist file can't be found
    public init(plistFileNameInBundle filename:String) throws {
        let bundlePath = Bundle.main.bundlePath as NSString
        let plistPath = bundlePath.appendingPathComponent(filename)
        plistDict = NSDictionary(contentsOfFile: plistPath)
        
        if plistDict == nil {
            throw PlistDictLoaderError.fileNotFound(name: plistPath)
        }
    }
    
    public enum DictValue {
    case intValue(Int)
    case stringValue(String)
    }
    
    public enum DictType {
    case intType
    case stringType
    }
    
    open func get(varName:String, ofType type:DictType = .stringType) -> DictValue? {
        switch type {
        case .intType:
            if let intVal = plistDict![varName] as? Int {
                return .intValue(intVal)
            }
            
        case .stringType:
            if let str = plistDict![varName] as? String {
                return .stringValue(str)
            }
        }
        
        return nil
    }
    
    // Throws an error if the value is not present.
    open func getRequired(varName:String, ofType type:DictType = .stringType) throws -> DictValue {
        if let result = get(varName: varName, ofType: type) {
            return result
        }
        else {
            throw PlistDictLoaderError.requiredVarNotFound(key: varName)
        }
    }
    
    open func getInt(varName key:String) throws -> Int {
        if case .intValue(let intValue) = try self.getRequired(varName: key) {
            return intValue
        }
        throw PlistDictLoaderError.requiredIntVarNotFound(key: key)
    }
    
    open func getString(varName key:String) throws -> String {
        if case .stringValue(let strValue) = try self.getRequired(varName: key) {
            return strValue
        }
        throw PlistDictLoaderError.requiredStringVarNotFound(key: key)
    }
}
