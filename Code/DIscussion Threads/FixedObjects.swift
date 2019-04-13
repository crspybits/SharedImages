//
//  FixedObjects.swift
//  SharedImages
//
//  Created by Christopher G Prince on 1/27/18.
//  Copyright © 2018 Spastic Muffin, LLC. All rights reserved.
//

/*
Provides support for a special type of file to reduce conflicts with SyncServer:

- JSON format
- Top level structure is a dictionary where the main element is an array of JSON dict objects
- Each of these objects has a unique id
- Once added, these objects *never* change
- Once added, these objects cannot be removed
- New objects can be added, with their unique id
- Objects are simply ordered-- in the order added; e.g., first added is first.

So, in terms of SyncServer and conflicts, resolving a conflict between a file download and a file upload for the same file will amount to ignoring the file download and ignoring the current file upload, but creating a new file upload containing all of the objects across upload and download. Those will be easily identified due to their unique id's. We won't have to worry about resolving conflicts within any object because they can't change.

Example:
{
    "imageUUID": "D5FEDC37-2B7C-47FC-B1A1-A8BB3C6E76E3",
    "imageTitle": "Christopher G. Prince",
    "elements": [
        {
            "senderId": "1",
            "id": "F5E48A66-36EA-42FF-B6F9-016882ACD495",
            "senderDisplayName": "Christopher G. Prince",
            "sendDate": "2019-03-25T02:25:09Z",
            "sendTimezone": "America\/Denver",
            "messageString": "Ta Da!"
        }
    ]
}

In terms of the members of the FixedObjects structure below, the `mainDictionary` is the overall object above. In this example, its keys are imageUUID, imageTitle, and elements. The first two keys (imageUUID, imageTitle) are caller selected-- i.e., the FixedObjects user/caller sets these. The `elements` key is special (only for internal use) and supports the properties as described above for simplifying conflict resolution.
*/

import Foundation
import SMCoreLib

struct FixedObjects: Sequence, Equatable {
    typealias ConvertableToJSON = Any
    typealias FixedObject = [String: ConvertableToJSON]
    typealias MainDictionary = [String: ConvertableToJSON]
    
    // It is an error for you to directly use this key to access the main dictionary.
    let elementsKey = "elements"
    
    private var mainDictionary = MainDictionary()
    private var elements = [Element]()
    
    fileprivate var ids = Set<String>()
    static let idKey = "id"
    
    // The number of `elements`s.
    var count: Int {
        return elements.count
    }
    
    // Get one of the components of `elements`. This assumes that the index is within range of count (above).
    subscript(index: Int) -> FixedObject {
        get {
            return elements[index]
        }
    }
    
    // Access the top-level (main) dictionary.
    subscript(index: String) -> ConvertableToJSON? {
        get {
            if index == elementsKey {
                Log.error("Cannot use key (getter): \(index)")
                return nil
            }
            else {
                return mainDictionary[index]
            }
        }
        
        set(newValue) {
            if index == elementsKey {
                Log.error("Cannot use key (setter): \(index)")
            }
            else {
                mainDictionary[index] = newValue
            }
        }
    }
    
    // Create empty sequence.
    public init() {
    }
    
    // Reads the file as JSON formatted contents.
    public init?(withFile localURL: URL) {
        var jsonObject:Any!
        
        do {
            let data = try Data(contentsOf: localURL)
            let jsonString = String(data: data, encoding: .utf8)
            Log.info("json: \(String(describing: jsonString))")
            jsonObject = try JSONSerialization.jsonObject(with: data, options: JSONSerialization.ReadingOptions(rawValue: 0))
        } catch {
            return nil
        }
        
        guard let mainDictionary = jsonObject as? MainDictionary,
            let elements = mainDictionary[elementsKey] as? [FixedObject] else {
            return nil
        }
        
        do {
            for fixedObject in elements {
                try add(newFixedObject: fixedObject)
            }
        } catch {
            return nil
        }
        
        self.mainDictionary = mainDictionary
    }
    
    enum Errors : Error {
        case noId
        case idIsNotNew
    }
    
    // The dictionary passed must have a key `id`; the value of that key must be a String, and it must not be the same as any other id for fixed objects added, or obtained through the init `withFile` constructor, previously.
    mutating func add(newFixedObject: FixedObject) throws {
        guard let newId = newFixedObject[FixedObjects.idKey] as? String else {
            throw Errors.noId
        }
        
        guard !ids.contains(newId) else {
            throw Errors.idIsNotNew
        }
        
        ids.insert(newId)
        elements += [newFixedObject]
    }
    
    // Duplicate FixedObjects are ignored-- they are assumed to be identical. Other keys/values in the main dictionaries are simply assigned into the main dictionary of the result, other first and then self (so self takes priority).
    // The `new` count is with respect to the FixedObjects in self: The number of new objects added in the merge from the other.
    func merge(with otherFixedObjects: FixedObjects) -> (FixedObjects, new: Int) {
        var mergedResult = FixedObjects()
        
        for fixedObject in self {
            try! mergedResult.add(newFixedObject: fixedObject)
        }
        
        var new = 0
        for otherFixedObject in otherFixedObjects {
            let id = otherFixedObject[FixedObjects.idKey] as! String
            if !ids.contains(id) {
                try! mergedResult.add(newFixedObject: otherFixedObject)
                new += 1
            }
        }
        
        for (mainDictKey, mainDictValue) in otherFixedObjects.mainDictionary {
            mergedResult.mainDictionary[mainDictKey] = mainDictValue
        }
        
        for (mainDictKey, mainDictValue) in self.mainDictionary {
            mergedResult.mainDictionary[mainDictKey] = mainDictValue
        }
        
        return (mergedResult, new)
    }
    
    // Saves current sequence of fixed objects, in JSON format, to the file.
    func save(toFile localURL: URL) throws {
        let data = try getData()
        try data.write(to: localURL)
    }
    
    private func getData() throws -> Data {
        var mainDictionary = self.mainDictionary
        mainDictionary[elementsKey] = elements
        return try JSONSerialization.data(withJSONObject: mainDictionary, options: JSONSerialization.WritingOptions(rawValue: 0))
    }
    
    // Adapted from https://digitalleaves.com/blog/2017/03/sequence-hacking-in-swift-iii-building-custom-sequences-for-fun-and-profit/
    func makeIterator() -> AnyIterator<FixedObject> {
        var index = 0
        return AnyIterator {
            var result: FixedObject?
            
            if index < self.elements.count {
                result = self.elements[index]
                index += 1
            }
            
            return result
        }
    }
    
    // Equality includes ordering of calls to `add`, i.e., ordering of the FixedObjects in the sequence. And contents of the main dictionary.
    static func ==(lhs: FixedObjects, rhs: FixedObjects) -> Bool {
        do {
            let data1 = try lhs.getData()
            let data2 = try rhs.getData()
            return data1 == data2
        }
        catch {
            return false
        }
    }
}

// Weaker equivalency: Just checks to make sure objects have each have the same ids. Doesn't check other contents of the objects in each. Doesn't include other key/values in main dictionary.
infix operator ~~
func ~~(lhs: FixedObjects, rhs: FixedObjects) -> Bool {
    return lhs.ids == rhs.ids
}

