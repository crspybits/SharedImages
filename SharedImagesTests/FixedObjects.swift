//
//  FixedObjects.swift
//  SharedImagesTests
//
//  Created by Christopher G Prince on 1/27/18.
//  Copyright © 2018 Spastic Muffin, LLC. All rights reserved.
//

import XCTest
@testable import SharedImages
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
}
