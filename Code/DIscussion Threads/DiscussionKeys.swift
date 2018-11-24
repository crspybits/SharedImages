//
//  DiscussionKeys.swift
//  SharedImages
//
//  Created by Christopher G Prince on 4/17/18.
//  Copyright © 2018 Spastic Muffin, LLC. All rights reserved.
//

import Foundation

class DiscussionKeys {
    // See [1] in ImagesVC.swift-- this is used as a comment.
    static let imageUUIDKey = "imageUUID"
    
    // 4/17/18; For some early files, image titles were stored in appMetaData. After server version 0.14.0, they are stored in "discussion" files. While the image title is stored in the "discussion" file-- that's for purposes of upload and download. Normally, we access the image title from the Core Data Image object title property.
    static let imageTitleKey = "imageTitle"
}
