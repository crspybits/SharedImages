//
//  TestProgressIndicator.swift
//  SharedImagesTests
//
//  Created by Christopher G Prince on 9/14/17.
//  Copyright © 2017 Spastic Muffin, LLC. All rights reserved.
//

import XCTest
@testable import SharedImages
import SMCoreLib

class TestProgressIndicator: XCTestCase {
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testShowOnce() {
        let exp = expectation(description: "Test")
        let progressIndicator = ProgressIndicator(imagesToDownload: 100, imagesToDelete: 0) {
            Log.msg("Pressed the Stop Button!")
            exp.fulfill()
        }
        progressIndicator.show()
        
        func update(_ number: Int) {
            TimedCallback.withDuration(1) {
                progressIndicator.updateProgress(withNumberDownloaded: UInt(number))
                if number < 30 {
                    update(number+1)
                }
                else {
                    exp.fulfill()
                }
            }
        }
        
        update(1)
        
        waitForExpectations(timeout: 60, handler: nil)
    }
    
    func testShowTwice() {
        let exp = expectation(description: "Test")
        var progressIndicator2:ProgressIndicator?
        var progressIndicator1 = ProgressIndicator(imagesToDownload: 100, imagesToDelete: 0) {
            Log.msg("Pressed the Stop Button!")
            
            progressIndicator2 = ProgressIndicator(imagesToDownload: 200, imagesToDelete: 0) {
                exp.fulfill()
            }
            
            progressIndicator2!.show()
        }
        
        progressIndicator1.show()
        
        func update(_ number: Int) {
            TimedCallback.withDuration(1) {
                let indicator = progressIndicator2 ?? progressIndicator1
                indicator.updateProgress(withNumberDownloaded: UInt(number))
                if number < 30 {
                    update(number+1)
                }
                else {
                    exp.fulfill()
                }
            }
        }
        
        update(1)
        
        waitForExpectations(timeout: 60, handler: nil)
    }
}
