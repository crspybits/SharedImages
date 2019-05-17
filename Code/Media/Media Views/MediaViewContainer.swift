//
//  MediaViewContainer.swift
//  SharedImages
//
//  Created by Christopher G Prince on 4/27/19.
//  Copyright © 2019 Spastic Muffin, LLC. All rights reserved.
//

import UIKit

protocol MediaView where Self: UIView {
    // The size needs to be computed to preserve the aspect ratio of the media you are rendering.
    func showWith(size: CGSize)
    
    func changeToFullsizedMediaForZooming()
}

class MediaViewContainer: UIView {
    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        setup()
    }
    
    private func setup() {
    }
    
    func setup(with media: MediaType, cache: LRUCache<ImageMediaObject>, backgroundColor: UIColor? = nil, albumsView: Bool = false) {
        switch media {
        case is ImageMediaObject:
            let imageView:ImageMediaView
            if let imv = mediaView as? ImageMediaView {
                imageView = imv
            }
            else {
                imageView = ImageMediaView()
                mediaView = imageView
            }
            
            imageView.setupWith(media: media as! ImageMediaObject, imageCache: cache)
            mediaView = imageView
            
        case is URLMediaObject:
            let urlView:URLMediaView
            if let umv = mediaView as? URLMediaView {
                urlView = umv
            }
            else {
                urlView = URLMediaView()
                mediaView = urlView
            }
            
            urlView.setupWith(media: media as! URLMediaObject, albumsView: albumsView)
            
            if let backgroundColor = backgroundColor {
                urlView.backgroundColor = backgroundColor
            }
            
            urlView.linkTapAction = { url in
                UIApplication.shared.open(url, options: [:], completionHandler: nil)
            }
            mediaView = urlView
            
        default:
            assert(false)
        }
    }
    
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
