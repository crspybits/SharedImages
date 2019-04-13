//
//  FixedObjects.swift
//  SharedImagesTests
//
//  Created by Christopher G Prince on 1/27/18.
//  Copyright © 2018 Spastic Muffin, LLC. All rights reserved.
//

import XCTest
@testable import Neebla
import SMCoreLib

class FixedObjectsTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testAddNewFixedObjectWorks() {
        var fixedObjects = FixedObjects()
        
        do {
            try fixedObjects.add(newFixedObject: [FixedObjects.idKey: "1"])
        } catch {
            XCTFail()
            return
        }
    }
    
    func testAddNewFixedObjectWithNoIdFails() {
        var fixedObjects = FixedObjects()
        
        do {
            try fixedObjects.add(newFixedObject: ["blah": 1])
            XCTFail()
        } catch {
        }
    }
    
    func testAddNewFixedObjectWithSameIdFails() {
        var fixedObjects = FixedObjects()

        do {
            try fixedObjects.add(newFixedObject: [FixedObjects.idKey: "1"])
        } catch {
            XCTFail()
            return
        }
        
        do {
            try fixedObjects.add(newFixedObject: [FixedObjects.idKey: "1"])
            XCTFail()
        } catch {
        }
    }
    
    @discardableResult
    func saveToFileWithJustId() -> (FixedObjects, URL)? {
        var fixedObjects = FixedObjects()

        let url = ImageExtras.newJSONFile()
        print("url: \(url)")
        do {
            try fixedObjects.add(newFixedObject: [FixedObjects.idKey: "1"])
            try fixedObjects.save(toFile: url as URL)
        } catch {
            XCTFail()
            return nil
        }
        
        return (fixedObjects, url as URL)
    }
    
    func testSaveToFileWithJustIdWorks() {
        saveToFileWithJustId()
    }
    
    @discardableResult
    func saveToFileWithIdAndOherContents() -> (FixedObjects, URL)? {
        var fixedObjects = FixedObjects()

        let url = ImageExtras.newJSONFile()
        print("url: \(url)")
        do {
            try fixedObjects.add(newFixedObject: [
                FixedObjects.idKey: "1",
                "Foobar": 1,
                "snafu": ["Nested": "object"]
            ])
            try fixedObjects.save(toFile: url as URL)
        } catch {
            XCTFail()
            return nil
        }
        
        return (fixedObjects, url as URL)
    }
    
    func testSaveToFileWithIdAndOherContentsWorks() {
        saveToFileWithIdAndOherContents()
    }
    
    @discardableResult
    func saveToFileWithQuoteInContents() -> (FixedObjects, URL)? {
        var fixedObjects = FixedObjects()

        let quote1 = "\""
        let quote2 = "'"
        
        let url = ImageExtras.newJSONFile()
        print("url: \(url)")
        do {
            try fixedObjects.add(newFixedObject: [
                FixedObjects.idKey: "1",
                "test1": quote1,
                "test2": quote2
            ])
            try fixedObjects.save(toFile: url as URL)
        } catch {
            XCTFail()
            return nil
        }
        
        return (fixedObjects, url as URL)
    }
    
    func testSaveToFileWithQuoteInContentsWorks() {
        saveToFileWithQuoteInContents()
    }
    
    func testEqualityForSameObjectsWorks() {
        let fixedObjects = FixedObjects()
        XCTAssert(fixedObjects == fixedObjects)
    }
    
    func testEqualityForEmptyObjectsWorks() {
        let fixedObjects1 = FixedObjects()
        let fixedObjects2 = FixedObjects()
        XCTAssert(fixedObjects1 == fixedObjects2)
    }
    
    func testNonEqualityForEmptyAndNonEmptyObjectsWorks() {
        var fixedObjects1 = FixedObjects()
        
        do {
            try fixedObjects1.add(newFixedObject: [FixedObjects.idKey: "1"])
        } catch {
            XCTFail()
            return
        }
        
        let fixedObjects2 = FixedObjects()
        
        XCTAssert(fixedObjects1 != fixedObjects2)
    }
    
    func testNonEqualityForSimilarObjectsWorks() {
        var fixedObjects1 = FixedObjects()
        do {
            try fixedObjects1.add(newFixedObject: [FixedObjects.idKey: "1"])
        } catch {
            XCTFail()
            return
        }
        
        var fixedObjects2 = FixedObjects()
        do {
            try fixedObjects2.add(newFixedObject: [FixedObjects.idKey: "2"])
        } catch {
            XCTFail()
            return
        }
        
        XCTAssert(fixedObjects1 != fixedObjects2)
    }

    func testEqualityForEquivalentObjectsWorks() {
        var fixedObjects1 = FixedObjects()
        do {
            try fixedObjects1.add(newFixedObject: [FixedObjects.idKey: "1"])
        } catch {
            XCTFail()
            return
        }
        
        var fixedObjects2 = FixedObjects()
        do {
            try fixedObjects2.add(newFixedObject: [FixedObjects.idKey: "1"])
        } catch {
            XCTFail()
            return
        }
        
        XCTAssert(fixedObjects1 == fixedObjects2)
    }
    
    func testObjectsDoNotChangeWhenWritten() {
        let testData:[(fixedObject: FixedObjects, url: URL)?] = [
            saveToFileWithJustId(),
            saveToFileWithIdAndOherContents(),
            saveToFileWithQuoteInContents()
        ]
        
        testData.forEach() { data in
            guard let data = data else {
                XCTFail()
                return
            }
            
            guard let fromFile = FixedObjects(withFile: data.url) else {
                XCTFail()
                return
            }
            
            XCTAssert(data.fixedObject == fromFile)
        }
    }
    
    func testEquivalanceWithNonEqualSameSizeWorks() {
        var fixedObjects1 = FixedObjects()
        do {
            try fixedObjects1.add(newFixedObject: [FixedObjects.idKey: "1"])
        } catch {
            XCTFail()
            return
        }
        
        var fixedObjects2 = FixedObjects()
        do {
            try fixedObjects2.add(newFixedObject: [FixedObjects.idKey: "2"])
        } catch {
            XCTFail()
            return
        }
        
        XCTAssert(!(fixedObjects1 ~~ fixedObjects2))
    }
    
    func testEquivalanceWithNonEqualsDiffSizeWorks() {
        var fixedObjects1 = FixedObjects()
        do {
            try fixedObjects1.add(newFixedObject: [FixedObjects.idKey: "1"])
        } catch {
            XCTFail()
            return
        }
        
        var fixedObjects2 = FixedObjects()
        do {
            try fixedObjects2.add(newFixedObject: [FixedObjects.idKey: "1"])
            try fixedObjects2.add(newFixedObject: [FixedObjects.idKey: "2"])
        } catch {
            XCTFail()
            return
        }
        
        XCTAssert(!(fixedObjects1 ~~ fixedObjects2))
    }
    
    func testMergeWithSameWorks() {
        var fixedObjects = FixedObjects()
        do {
            try fixedObjects.add(newFixedObject: [FixedObjects.idKey: "1"])
        } catch {
            XCTFail()
            return
        }
        
        let (result, unread) = fixedObjects.merge(with: fixedObjects)
        XCTAssert(unread  == 0)
        XCTAssert(fixedObjects ~~ result)
        XCTAssert(result.count == 1)
    }
    
    func testMergeNeitherHaveObjectsWorks() {
        let fixedObjects1 = FixedObjects()
        let fixedObjects2 = FixedObjects()
        
        let (result, unread) = fixedObjects1.merge(with: fixedObjects2)
        XCTAssert(unread  == 0)
        XCTAssert(fixedObjects1 ~~ result)
        XCTAssert(result.count == 0)
    }

    func testMergeOnlyHaveSameObjectWorks() {
        var fixedObjects1 = FixedObjects()
        do {
            try fixedObjects1.add(newFixedObject: [FixedObjects.idKey: "1"])
        } catch {
            XCTFail()
            return
        }
        
        var fixedObjects2 = FixedObjects()
        do {
            try fixedObjects2.add(newFixedObject: [FixedObjects.idKey: "1"])
        } catch {
            XCTFail()
            return
        }
        
        let (result, unread) = fixedObjects1.merge(with: fixedObjects2)
        XCTAssert(unread  == 0)
        XCTAssert(fixedObjects1 ~~ result)
        XCTAssert(result.count == 1)
    }

    func testMergeHaveSomeSameObjectsWorks() {
        var standard = FixedObjects()
        do {
            try standard.add(newFixedObject: [FixedObjects.idKey: "1"])
            try standard.add(newFixedObject: [FixedObjects.idKey: "2"])
            try standard.add(newFixedObject: [FixedObjects.idKey: "3"])
        } catch {
            XCTFail()
            return
        }
        
        var fixedObjects1 = FixedObjects()
        do {
            try fixedObjects1.add(newFixedObject: [FixedObjects.idKey: "1"])
            try fixedObjects1.add(newFixedObject: [FixedObjects.idKey: "2"])
        } catch {
            XCTFail()
            return
        }
        
        var fixedObjects2 = FixedObjects()
        do {
            try fixedObjects2.add(newFixedObject: [FixedObjects.idKey: "1"])
            try fixedObjects2.add(newFixedObject: [FixedObjects.idKey: "3"])
        } catch {
            XCTFail()
            return
        }
        
        let (result, unread) = fixedObjects1.merge(with: fixedObjects2)
        XCTAssert(unread == 1)
        XCTAssert(result ~~ standard)
        XCTAssert(result.count == 3)
    }
    
    func testMergeHaveNoSameObjectsWorks() {
        var standard = FixedObjects()
        do {
            try standard.add(newFixedObject: [FixedObjects.idKey: "1"])
            try standard.add(newFixedObject: [FixedObjects.idKey: "2"])
            try standard.add(newFixedObject: [FixedObjects.idKey: "3"])
            try standard.add(newFixedObject: [FixedObjects.idKey: "4"])
        } catch {
            XCTFail()
            return
        }
        
        var fixedObjects1 = FixedObjects()
        do {
            try fixedObjects1.add(newFixedObject: [FixedObjects.idKey: "1"])
            try fixedObjects1.add(newFixedObject: [FixedObjects.idKey: "2"])
        } catch {
            XCTFail()
            return
        }
        
        var fixedObjects2 = FixedObjects()
        do {
            try fixedObjects2.add(newFixedObject: [FixedObjects.idKey: "3"])
            try fixedObjects2.add(newFixedObject: [FixedObjects.idKey: "4"])
        } catch {
            XCTFail()
            return
        }
        
        let (result, unread) = fixedObjects1.merge(with: fixedObjects2)
        XCTAssert(unread == 2, "unread: \(unread)")
        XCTAssert(result ~~ standard)
        XCTAssert(result.count == 4)
    }
    
    // MARK: Main dictionary contents
    
    func testSetAndGetMainDictionaryElementInt() {
        var example = FixedObjects()
        let key = "test"
        let value = 1
        example[key] = value
        guard let result = example[key] as? Int, result == value else {
            XCTFail()
            return
        }
    }
    
    func testSetAndGetMainDictionaryElementString() {
        var example = FixedObjects()
        let key = "test"
        let value = "Hello World!"
        example[key] = value
        guard let result = example[key] as? String, result == value else {
            XCTFail()
            return
        }
    }
    
    func testSetAndGetMainDictionaryElementIntAndString() {
        var example = FixedObjects()
        
        let key1 = "test1"
        let value1 = "Hello World!"
        example[key1] = value1
        
        let key2 = "test2"
        let value2 = 42
        example[key2] = value2
        
        guard let result1 = example[key1] as? String, result1 == value1,
            let result2 = example[key2] as? Int, result2 == value2 else {
            XCTFail()
            return
        }
    }
    
    func testSaveAndLoadMainDictionary() {
        var example = FixedObjects()
        
        let key1 = "test1"
        let value1 = "Hello World!"
        example[key1] = value1
        
        let key2 = "test2"
        let value2 = 42
        example[key2] = value2
        
        let url = ImageExtras.newJSONFile()
        print("url: \(url)")
        do {
            try example.save(toFile: url as URL)
        } catch {
            XCTFail()
            return
        }
        
        guard let fromFile = FixedObjects(withFile: url as URL) else {
            XCTFail()
            return
        }
        
        guard let result1 = fromFile[key1] as? String, result1 == value1,
            let result2 = fromFile[key2] as? Int, result2 == value2 else {
            XCTFail()
            return
        }
    }
    
    func testSaveAndLoadWithMainDictElementsAndFixedObjects() {
        var example = FixedObjects()
        
        let key1 = "test1"
        let value1 = "Hello World!"
        example[key1] = value1
        
        let key2 = "test2"
        let value2 = 42
        example[key2] = value2
        
        do {
            try example.add(newFixedObject: [FixedObjects.idKey: "1"])
            try example.add(newFixedObject: [FixedObjects.idKey: "2"])
        } catch {
            XCTFail()
            return
        }
        
        let url = ImageExtras.newJSONFile()
        print("url: \(url)")
        do {
            try example.save(toFile: url as URL)
        } catch {
            XCTFail()
            return
        }
        
        guard let fromFile = FixedObjects(withFile: url as URL) else {
            XCTFail()
            return
        }
        
        guard let result1 = fromFile[key1] as? String, result1 == value1,
            let result2 = fromFile[key2] as? Int, result2 == value2,
            example == fromFile, example ~~ fromFile,
            fromFile.count == example.count else {
            XCTFail()
            return
        }
    }
    
    func testMergeWorksWhenThereAreMainDictionaryElements_NonOverlapping() {
        var example1 = FixedObjects()
        
        let key1 = "test1"
        let value1 = "Hello World!"
        example1[key1] = value1
        
        let key2 = "test2"
        let value2 = 42
        example1[key2] = value2
        
        var example2 = FixedObjects()
        
        let key3 = "test3"
        let value3 = 98
        example2[key3] = value3

        let (mergedResult, _) = example1.merge(with: example2)
        
        guard let result1 = mergedResult[key1] as? String,
            let result2 = mergedResult[key2] as? Int,
            let result3 = mergedResult[key3] as? Int else {
            XCTFail()
            return
        }
        
        XCTAssert(result1 == value1)
        XCTAssert(result2 == value2)
        XCTAssert(result3 == value3)
    }
    
    func testMergeWorksWhenThereAreMainDictionaryElements_Overlapping() {
        var example1 = FixedObjects()
        
        let key1 = "test1"
        let value1 = "Hello World!"
        example1[key1] = value1
        
        let key2 = "test2"
        let value2 = 42
        example1[key2] = value2
        
        var example2 = FixedObjects()
        
        let key3 = "test2"
        let value3 = 98
        example2[key3] = value3

        let (mergedResult, _) = example1.merge(with: example2)
        
        guard let result1 = mergedResult[key1] as? String,
            let result2 = mergedResult[key2] as? Int,
            let result3 = mergedResult[key3] as? Int else {
            XCTFail()
            return
        }
        
        XCTAssert(result1 == value1)
        XCTAssert(result2 == value2)
        XCTAssert(result3 == value2)
    }
}

