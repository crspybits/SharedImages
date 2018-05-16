//
//  FileGroupTests.swift
//  SharedImagesTests
//
//  Created by Christopher G Prince on 5/13/18.
//  Copyright © 2018 Spastic Muffin, LLC. All rights reserved.
//

import XCTest
@testable import SharedImages
import SMCoreLib

class FileGroupTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testGroupUUID() {
        let fileGroupUUID = UUID.make()!
        let newDiscussion = Discussion.newObjectAndMakeUUID(makeUUID: true) as! Discussion
        newDiscussion.fileGroupUUID = fileGroupUUID
        let newImage = Image.newObjectAndMakeUUID(makeUUID: true) as! Image
        newImage.fileGroupUUID = fileGroupUUID
        CoreData.sessionNamed(CoreDataExtras.sessionName).saveContext()

        guard let discussion = Discussion.fetchObjectWithFileGroupUUID(fileGroupUUID), discussion.uuid == newDiscussion.uuid else {
            XCTFail()
            return
        }
        
        guard let image = Image.fetchObjectWithFileGroupUUID(fileGroupUUID),
            image.uuid == newImage.uuid else {
            XCTFail()
            return
        }
    }
}
