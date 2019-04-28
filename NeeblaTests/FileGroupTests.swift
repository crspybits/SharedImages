//
//  FileGroupTests.swift
//  SharedImagesTests
//
//  Created by Christopher G Prince on 5/13/18.
//  Copyright © 2018 Spastic Muffin, LLC. All rights reserved.
//

import XCTest
@testable import Neebla
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
        let sharingGroupUUID = UUID().uuidString
        let fileGroupUUID = UUID.make()!
        let newDiscussion = DiscussionFileObject.newObjectAndMakeUUID(makeUUID: true) as! DiscussionFileObject
        newDiscussion.fileGroupUUID = fileGroupUUID
        newDiscussion.sharingGroupUUID = sharingGroupUUID
        let newImage = ImageMediaObject.newObjectAndMakeUUID(makeUUID: true) as! ImageMediaObject
        newImage.fileGroupUUID = fileGroupUUID
        newImage.sharingGroupUUID = sharingGroupUUID
        CoreData.sessionNamed(CoreDataExtras.sessionName).saveContext()

        guard let discussion = DiscussionFileObject.fetchObjectWithFileGroupUUID(fileGroupUUID), discussion.uuid == newDiscussion.uuid else {
            XCTFail()
            return
        }
        
        guard let image = ImageMediaObject.fetchObjectWithFileGroupUUID(fileGroupUUID),
            image.uuid == newImage.uuid else {
            XCTFail()
            return
        }
    }
}

