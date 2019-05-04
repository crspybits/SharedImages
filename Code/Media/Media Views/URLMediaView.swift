//
//  URLMediaView.swift
//  SharedImages
//
//  Created by Christopher G Prince on 5/2/19.
//  Copyright © 2019 Spastic Muffin, LLC. All rights reserved.
//

import UIKit

class URLMediaView: UIView, MediaView {
    private var media: URLMediaObject!
    
    func setupWith(media: URLMediaObject) {
        self.media = media
        backgroundColor = .green
    }
    
    func showWith(size: CGSize) {
    }
    
    func changeToFullsizedMediaForZooming() {
    }
}
