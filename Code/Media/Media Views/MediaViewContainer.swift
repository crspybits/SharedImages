//
//  MediaViewContainer.swift
//  SharedImages
//
//  Created by Christopher G Prince on 4/27/19.
//  Copyright © 2019 Spastic Muffin, LLC. All rights reserved.
//

import UIKit

protocol MediaView where Self: UIView {
    var originalSize: CGSize? {get}
    func showWith(size: CGSize)
    func changeToFullsizedMediaForZooming()
}

class MediaViewContainer: UIView {
    // Removes any existing prior mediaView from the view hierarchy before adding this, if non-nil.
    var mediaView: MediaView? {
        didSet {
            subviews.forEach { view in
                if let mediaView = view as? MediaView {
                    mediaView.removeFromSuperview()
                }
            }
            
            if let mediaView = mediaView {
                addSubview(mediaView)
                mediaView.leftAnchor.constraint(equalTo: leftAnchor).isActive = true
                mediaView.rightAnchor.constraint(equalTo: rightAnchor).isActive = true
                mediaView.topAnchor.constraint(equalTo: topAnchor).isActive = true
                mediaView.bottomAnchor.constraint(equalTo: bottomAnchor).isActive = true
                mediaView.translatesAutoresizingMaskIntoConstraints = false
            }
        }
    }
}
