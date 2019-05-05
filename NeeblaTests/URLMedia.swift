//
//  URLMedia.swift
//  NeeblaTests
//
//  Created by Christopher G Prince on 5/4/19.
//  Copyright © 2019 Spastic Muffin, LLC. All rights reserved.
//

@testable import Neebla
import XCTest

class URLMedia: XCTestCase {

    override func setUp() {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testWriteURLFileWorks() {
        let contents = URLMediaObject.URLFileContents(url: URL(string: "http://cprince.com")!, title: "Some title", imageType: nil)
        let url = URLMediaObject.createLocalURLFile(contents: contents)
        XCTAssert(url != nil)
    }
    
    func testReadURLFileWithURLAndTitleAndImageTypeWorks() {
        let contents = URLMediaObject.URLFileContents(url: URL(string: "http://cprince.com")!, title: "Some title", imageType: .large)
        guard let url = URLMediaObject.createLocalURLFile(contents: contents) else {
            XCTFail()
            return
        }
        
        guard let parsedContents = URLMediaObject.parseURLFile(localURLFile: url as URL) else {
            XCTFail()
            return
        }
        
        XCTAssert(parsedContents.title == contents.title)
        XCTAssert(parsedContents.url == contents.url)
        XCTAssert(parsedContents.imageType == contents.imageType)
    }
    
    func testReadURLFileWithURLAndTitleWorks() {
        let contents = URLMediaObject.URLFileContents(url: URL(string: "http://cprince.com")!, title: "Some title", imageType: nil)
        guard let url = URLMediaObject.createLocalURLFile(contents: contents) else {
            XCTFail()
            return
        }
        
        guard let parsedContents = URLMediaObject.parseURLFile(localURLFile: url as URL) else {
            XCTFail()
            return
        }
        
        XCTAssert(parsedContents.title == contents.title)
        XCTAssert(parsedContents.url == contents.url)
        XCTAssert(parsedContents.imageType == contents.imageType)
    }
    
    func testReadURLFileWithURLOnlyWorks() {
        let contents = URLMediaObject.URLFileContents(url: URL(string: "http://cprince.com")!, title: nil, imageType: nil)
        guard let url = URLMediaObject.createLocalURLFile(contents: contents) else {
            XCTFail()
            return
        }
        
        guard let parsedContents = URLMediaObject.parseURLFile(localURLFile: url as URL) else {
            XCTFail()
            return
        }
        
        XCTAssert(parsedContents.title == contents.title)
        XCTAssert(parsedContents.url == contents.url)
        XCTAssert(parsedContents.imageType == contents.imageType)
    }
}
