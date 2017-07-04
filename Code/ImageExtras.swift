//
//  ImageExtras.swift
//  SharedImages
//
//  Created by Christopher Prince on 6/6/17.
//  Copyright © 2017 Spastic Muffin, LLC. All rights reserved.
//

import Foundation
import SMCoreLib

enum SortingOrder : String {
case newerAtTop
case newerAtBottom
}

class ImageExtras {
    static var currentSortingOrder = SMPersistItemString(name:"ImageExtras.currentSortingOrder", initialStringValue:SortingOrder.newerAtBottom.rawValue,  persistType: .userDefaults)
    
    static let iconDirectory = "SmallImages"
    static let iconDirectoryURL = FileStorage.url(ofItem: iconDirectory)
    static let largeImageDirectoryURL = FileStorage.url(ofItem: FileExtras.defaultDirectoryPath)

    // For some idea of free RAM available: https://stackoverflow.com/questions/5887248/ios-app-maximum-memory-budget
    static var minCostCache:UInt64 = 1000000
    static var maxCostCache:UInt64 = 10000000
    static var imageCache = LRUCache<Image>(maxItems: 500, maxCost:maxCostCache)!

    // Resets to smaller if not already at smaller size; only if reset is done will callback be called.
    static func resetToSmallerImageCache(didTheReset:()->()) {
        if imageCache.maxCost == maxCostCache {
            imageCache = LRUCache<Image>(maxItems: 500, maxCost:minCostCache)!
            didTheReset()
        }
    }

    static let appMetaDataTitleKey = "title"
    
    static func imageFileName(url:URL) -> String {
        return url.lastPathComponent
    }
    
    static func sizeFromFile(url:URL) -> CGSize {
        return ImageStorage.size(ofImage: imageFileName(url:url), withPath: largeImageDirectoryURL)
    }
    
    // Get the size of the icon without distorting the aspect ratio. Adapted from https://gist.github.com/tomasbasham/10533743
    static func boundingImageSizeFor(originalSize:CGSize, boundingSize:CGSize) -> CGSize {
        let aspectWidth = boundingSize.width / originalSize.width
        let aspectHeight = boundingSize.height / originalSize.height
        let aspectRatio = min(aspectWidth, aspectHeight)

        return CGSize(width: originalSize.width * aspectRatio, height: originalSize.height * aspectRatio)
    }

    static func removeLocalImage(uuid:String) {
        guard let image = Image.fetchObjectWithUUID(uuid: uuid) else {
            Log.error("Cannot find image with UUID: \(uuid)")
            return
        }
        
        CoreData.sessionNamed(CoreDataExtras.sessionName).remove(image)
        CoreData.sessionNamed(CoreDataExtras.sessionName).saveContext()
    }
}
