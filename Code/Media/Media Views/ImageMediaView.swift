//
//  ImageMediaView.swift
//  SharedImages
//
//  Created by Christopher G Prince on 4/27/19.
//  Copyright © 2019 Spastic Muffin, LLC. All rights reserved.
//

import UIKit

class ImageMediaView: UIImageView, MediaView {
    private weak var imageCache:LRUCache<ImageMediaObject>?
    private var media: ImageMediaObject!
    
    func setupWith(media: ImageMediaObject, imageCache: LRUCache<ImageMediaObject>) {
        self.imageCache = imageCache
        self.media = media
    }
    
    func showWith(size: CGSize) {
        DispatchQueue.global().async {[weak self] in
            if let self = self, let imageCache = self.imageCache {
                let cachedImage = imageCache.getItem(from: self.media, with: size)
                
                DispatchQueue.main.async {
                    // Apparent crash here on 10/17/17-- iPhone 6, reported via Apple/Xcode
                    // 11/29/17; I just got it again, while running attached to the debugger. In this case, `imageCache` was nil. I added a guard statement above to deal with this.
                    self.image = cachedImage
                }
            }
        }
    }
    
    func changeToFullsizedMediaForZooming() {
        let uiImage = ImageExtras.fullSizedImage(url: media.url! as URL)
        image = uiImage
    }
}
