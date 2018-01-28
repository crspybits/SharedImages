//
//  FixedObjects.swift
//  SharedImages
//
//  Created by Christopher G Prince on 1/27/18.
//  Copyright © 2018 Spastic Muffin, LLC. All rights reserved.
//

/*
Provides upport for a special type of file to reduce conflicts with SyncServer:

- JSON format
- Top level structure is an array of JSON dict objects
- Each of these objects has a unique id
- Once added, these objects *never* change
- Once added, these objects cannot be removed
- New objects can be added, with their unique id
- Objects are simply ordered-- in the order added; e.g., first added is first.

So, in terms of SyncServer and conflicts, resolving a conflict between a file download and a file upload for the same file will amount to ignoring the file download and ignoring the current file upload, but creating a new file upload containing all of the objects across upload and download. Those will be easily identified due to their unique id's. We won't have to worry about resolving conflicts within any object because they can't change.
*/

import Foundation

struct FixedObjects: Sequence, Equatable {
    typealias ConvertableToJSON = Any
    typealias FixedObject = [String: ConvertableToJSON]
    private var contents = [Element]()
    private var ids = Set<String>()
    static let idKey = "id"
    
    // Create empty sequence.
    public init() {
    }
    
    // Reads the file as JSON formatted contents.
    public init?(withFile localURL: URL) {
        var jsonObject:Any!
        
        do {
            let data = try Data(contentsOf: localURL)
            jsonObject = try JSONSerialization.jsonObject(with: data, options: JSONSerialization.ReadingOptions(rawValue: 0))
        } catch {
            return nil
        }
        
        guard let contents = jsonObject as? [FixedObject] else {
            return nil
        }
        
        do {
            for fixedObject in contents {
                try add(newFixedObject: fixedObject)
            }
        } catch {
            return nil
        }
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
        contents += [newFixedObject]
    }
    
    // Saves current sequence of fixed objects, in JSON format, to the file.
    func save(toFile localURL: URL) throws {
        let data = try getData()
        try data.write(to: localURL)
    }
    
    private func getData() throws -> Data {
        return try JSONSerialization.data(withJSONObject: contents, options: JSONSerialization.WritingOptions(rawValue: 0))
    }
    
    // Adapted from https://digitalleaves.com/blog/2017/03/sequence-hacking-in-swift-iii-building-custom-sequences-for-fun-and-profit/
    func makeIterator() -> AnyIterator<FixedObject> {
        var index = 0
        return AnyIterator {
            var result: FixedObject?
            
            if index < self.contents.count {
                result = self.contents[index]
                index += 1
            }
            
            return result
        }
    }
    
    // Equality includes ordering of calls to `add`, i.e., ordering of the FixedObjects in the sequence.
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

