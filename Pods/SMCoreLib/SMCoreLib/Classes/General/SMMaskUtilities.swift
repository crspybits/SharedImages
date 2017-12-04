//
//  SMMaskUtilities.swift
//  SMCoreLib
//
//  Created by Christopher Prince on 6/16/16.
//  Copyright © 2016 Spastic Muffin, LLC. All rights reserved.
//

import Foundation

open class SMMaskUtilities {
    open static func enumDescription(rawValue:Int, allAsStrings: [String]) -> String {
        var shift = 0
        while (rawValue >> shift != 1) {
            shift += 1
        }
        return allAsStrings[shift]
    }
    
    open static func maskDescription(stringArray:[String]) -> String {
        var result = ""

        for value in stringArray {
            result += (result.characters.count == 0) ? value : ",\(value)"
        }

        return "[\(result)]"
    }
    
    // An array of strings, possibly empty.
    open static func maskArrayOfStrings
        <StructType: OptionSet, EnumType: RawRepresentable>
        (_ maskObj:StructType, contains:(_ maskObj:StructType, _ enumValue:EnumType)-> Bool) -> [String] where EnumType.RawValue == Int {
        
        var result = [String]()
        var shift = 0

        while let enumValue = EnumType(rawValue: 1 << shift) {
            shift += 1
            if contains(maskObj, enumValue) {
                result.append("\(enumValue)")
            }
        }

        return result
    }
}
