//
//  URLMediaType.swift
//  SharedImages
//
//  Created by Christopher G Prince on 4/28/19.
//  Copyright © 2019 Spastic Muffin, LLC. All rights reserved.
//

import Foundation

extension URLMediaObject: MediaType {
    func checkForReadProblem(mediaData: MediaData) -> Bool {
        return true
    }
    
    func setup(mediaData: MediaData) {
    }
    
    // Also removes associated discussions.
    static func removeLocalMedia(uuid:String) -> Bool {
        assert(false)
        return false
    }
}
