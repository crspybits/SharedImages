//
//  URLMediaType.swift
//  SharedImages
//
//  Created by Christopher G Prince on 4/28/19.
//  Copyright © 2019 Spastic Muffin, LLC. All rights reserved.
//

import Foundation

extension URLMediaObject: MediaType {
    var originalSize: CGSize? {
        return nil
    }
    
    func checkForReadProblem(mediaData: MediaData) -> Bool {
        // TODO: Need to read file and see if have a read problem.
        return false
    }
    
    func setup(mediaData: MediaData) {
    }
    
    // Also removes associated discussions.
    static func removeLocalMedia(uuid:String) -> Bool {
        return FileMediaObject.remove(uuid: uuid)
    }
}
