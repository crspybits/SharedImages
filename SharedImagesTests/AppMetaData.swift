//
//  AppMetaData.swift
//  SharedImagesTests
//
//  Created by Christopher G Prince on 1/27/18.
//  Copyright © 2018 Spastic Muffin, LLC. All rights reserved.
//

import XCTest

class AppMetaData: XCTestCase {
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func dictToJSONString(_ dict: [String: Any]) -> String? {
        guard let data = try? JSONSerialization.data(withJSONObject: dict, options: JSONSerialization.WritingOptions(rawValue: 0)) else {
            XCTFail()
            return nil
        }
        
        guard let jsonString = String(data: data, encoding: String.Encoding.utf8) else {
            XCTFail()
            return nil
        }
        
        return jsonString
    }
    
    func testExample() {
        let jsonObject = ["foo" : "bar"]
        
        guard let jsonString = dictToJSONString(jsonObject) else {
            XCTFail()
            return
        }
        
        print("jsonString: \(jsonString)")
    }
}
