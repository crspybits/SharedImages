//
//  DiscussionKeys.swift
//  SharedImages
//
//  Created by Christopher G Prince on 4/17/18.
//  Copyright © 2018 Spastic Muffin, LLC. All rights reserved.
//

import Foundation

class DiscussionKeys {
    // 4/29/18; I have changed from `image` terminology (e.g., imageUUIDKey) to `media` terminlogy. But, of course, the keys themselves need to stay the same-- as they reflect what is in actual files.
    
    // See [1] in MediaVC.swift-- this is used as a comment.
    static let mediaUUIDKey = "imageUUID"
    
    // 4/17/18; For some early files, image titles were stored in appMetaData. After server version 0.14.0, they are stored in "discussion" files. While the image title is stored in the "discussion" file-- that's for purposes of upload and download. Normally, we access the image title from the Core Data Image object title property.
    static let mediaTitleKey = "imageTitle"
}
