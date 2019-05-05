//
//  URLMediaView.swift
//  SharedImages
//
//  Created by Christopher G Prince on 5/2/19.
//  Copyright © 2019 Spastic Muffin, LLC. All rights reserved.
//

import UIKit
import SMLinkPreview
import SMCoreLib

class URLMediaView: UIView, MediaView {
    private var media: URLMediaObject!
    private var content: UIView!

    private enum ContentType {
        case icon
        case preview
        
        func viewTypeOf() -> AnyObject.Type {
            switch self {
            case .icon:
                return URLIcon.self
            case .preview:
                return LinkPreview.self
            }
        }
    }
    
    override var bounds: CGRect {
        didSet {
            // See https://stackoverflow.com/questions/4000664/is-there-a-uiview-resize-event for the reason for putting this here and not in layoutSubviews.
            createContentIfNeeded()
        }
    }
    
    // This call is size dependent-- i.e., its effect is dependent on the size of the self's frame.
    private func createContentIfNeeded() {
        let contentType:ContentType =
            min(frameSize.width, frameSize.height) <= 100 ? .icon : .preview
        
        if let content = content, type(of: content) == contentType.viewTypeOf() {
            return
        }

        content?.removeFromSuperview()
        
        switch contentType {
        case .icon:
            let iconView = URLIcon.create()
            
            if let previewImageURL = media.previewImage?.url,
                let filePath = previewImageURL.path {
                // TODO: Loading needs to be async
                iconView?.image.image = UIImage(contentsOfFile: filePath)
            }
            
            content = iconView
            addSubview(content)
            content.leftAnchor.constraint(equalTo: leftAnchor).isActive = true
            content.rightAnchor.constraint(equalTo: rightAnchor).isActive = true
            content.topAnchor.constraint(equalTo: topAnchor).isActive = true
            content.bottomAnchor.constraint(equalTo: bottomAnchor).isActive = true
        case .preview:
            guard let localMediaURL = media.url else {
                return
            }
            
            // TODO: Will want to make this file read async, especially when we get to loading image data from a file. And the image read below too.
            guard let contents = URLMediaObject.parseURLFile(localURLFile: localMediaURL as URL) else {
                return
            }
            
            var iconURL: URL?
            var largeImageURL: URL?
            
            if let localImageURL = media.previewImage?.url,
                let imageType = contents.imageType {
                
                switch imageType {
                case .icon:
                    iconURL = localImageURL as URL
                case .large:
                    largeImageURL = localImageURL as URL
                }
            }
            
            // TODO: Have image loading from file in here. Need to make async.
            let linkData = LinkData(url: contents.url, title: contents.title, description: nil, image: largeImageURL, icon: iconURL)
            
            content = LinkPreview.create(with: linkData)
            addSubview(content)
            content.heightAnchor.constraint(equalToConstant: content.frameHeight).isActive = true
            content.widthAnchor.constraint(equalToConstant: content.frameWidth).isActive = true
            content.centerXAnchor.constraint(equalTo: centerXAnchor).isActive = true
            content.centerYAnchor.constraint(equalTo: centerYAnchor).isActive = true
        }
        
        content.translatesAutoresizingMaskIntoConstraints = false
    }
    
    func setupWith(media: URLMediaObject) {
        self.media = media
        backgroundColor = .white
    }
    
    func showWith(size: CGSize) {
    }
    
    func changeToFullsizedMediaForZooming() {
    }
}
