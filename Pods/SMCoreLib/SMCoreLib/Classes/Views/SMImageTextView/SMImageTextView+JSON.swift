//
//  SMImageTextView+JSON.swift
//  SMCoreLib
//
//  Created by Christopher Prince on 6/2/16.
//  Copyright © 2016 Spastic Muffin, LLC. All rights reserved.
//

import Foundation

public extension SMImageTextView {
    public func contentsToData() -> Data? {
        guard let currentContents = self.contents
        else {
            return nil
        }
        
        return SMImageTextView.contentsToData(currentContents)
    }
    
    public class func contentsToData(_ contents:[ImageTextViewElement]) -> Data? {
        // First create array of dictionaries.
        var array = [[String:AnyObject]]()
        for elem in contents {
            array.append(elem.toDictionary())
        }
        
        var jsonData:Data?
        
        do {
            try jsonData = JSONSerialization.data(withJSONObject: array, options: JSONSerialization.WritingOptions(rawValue: 0))
        } catch (let error) {
            Log.error("Error serializing array to JSON data: \(error)")
            return nil
        }

        let jsonString = NSString(data: jsonData!, encoding: String.Encoding.utf8.rawValue) as String?

        Log.msg("json results: \(String(describing: jsonString))")
        
        return jsonData
    }
    
    public func saveContents(toFileURL fileURL:URL) -> Bool {
        guard let jsonData = self.contentsToData()
        else {
            return false
        }
        
        do {
            try jsonData.write(to: fileURL, options: .atomicWrite)
        } catch (let error) {
            Log.error("Error writing JSON data to file: \(error)")
            return false
        }
        
        return true
    }
    
    // Give populateImagesUsing as non-nil to populate the images.
    fileprivate class func contents(fromJSONData jsonData:Data?, populateImagesUsing smImageTextView:SMImageTextView?) -> [ImageTextViewElement]? {
        var array:[[String:AnyObject]]?
        
        if jsonData == nil {
            return nil
        }

        do {
            try array = JSONSerialization.jsonObject(with: jsonData!, options: JSONSerialization.ReadingOptions(rawValue: 0)) as? [[String : AnyObject]]
        } catch (let error) {
            Log.error("Error converting JSON data to array: \(error)")
            return nil
        }

        if array == nil {
            return nil
        }
        
        var results = [ImageTextViewElement]()
        
        for dict in array! {
            if let elem = ImageTextViewElement.fromDictionary(dict) {
                var elemToAdd = elem
                
                switch elem {
                case .image(_, let uuid, let range):
                    if smImageTextView == nil {
                        elemToAdd = .image(nil, uuid, range)
                    }
                    else {
                        if let image = smImageTextView!.imageDelegate?.smImageTextView(smImageTextView!, imageForUUID: uuid!) {
                            elemToAdd = .image(image, uuid, range)
                        }
                        else {
                            return nil
                        }
                    }
                    
                default:
                    break
                }
                
                results.append(elemToAdd)
            }
            else {
                return nil
            }
        }
        
        return results
    }

    public class func contents(fromJSONData jsonData:Data?) -> [ImageTextViewElement]? {
        return self.contents(fromJSONData: jsonData, populateImagesUsing: nil)
    }
    
    // Concatenates all of the string components. Ignores the images.
    public class func contentsAsConcatenatedString(fromJSONData jsonData:Data?) -> String? {
        if let contents = SMImageTextView.contents(fromJSONData: jsonData) {
            var result = ""
    
            for elem in contents {
                switch elem {
                case .Text(let string, _):
                    result += string
                    
                default:
                    break
                }
            }
            
            return result
        }
        
        return nil
    }
    
    public func loadContents(fromJSONData jsonData:Data?) -> Bool {
        self.contents = SMImageTextView.contents(fromJSONData: jsonData, populateImagesUsing: self)
        return self.contents == nil ? false : true
    }
    
    public func loadContents(fromJSONFileURL fileURL:URL) -> Bool {
        guard let jsonData = try? Data(contentsOf: fileURL)
        else {
            return false
        }
        
        return self.loadContents(fromJSONData: jsonData)
    }
}
