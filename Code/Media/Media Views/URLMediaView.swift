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
    private var iconView:URLIcon!

    private var content: UIView! {
        return iconView ?? linkPreview ?? nil
    }
    
    private var linkPreview: LinkPreview!

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
    
    private var albumsView: Bool = false
    
    let minimimPreviewSize: CGFloat = 150
    var linkTapAction:((URL)->())?
    
    private var contentType:ContentType {
        return min(frameSize.width, frameSize.height) <= minimimPreviewSize ? .icon : .preview
    }
    
    override var bounds: CGRect {
        didSet {
            // See https://stackoverflow.com/questions/4000664/is-there-a-uiview-resize-event for the reason for putting this here and not in layoutSubviews.
            createContentViewIfNeeded()
        }
    }
    
    // This call is size dependent-- i.e., its effect is dependent on the size of the self's frame.
    private func createContentViewIfNeeded() {
        let contentType = self.contentType
        if let content = content, type(of: content) == contentType.viewTypeOf() {
            loadContentIntoView(contentType: contentType)
            return
        }

        content?.removeFromSuperview()
        iconView = nil
        linkPreview = nil
        
        switch contentType {
        case .icon:
            iconView = URLIcon.create()
            addSubview(iconView)
            iconView.leftAnchor.constraint(equalTo: leftAnchor).isActive = true
            iconView.rightAnchor.constraint(equalTo: rightAnchor).isActive = true
            iconView.topAnchor.constraint(equalTo: topAnchor).isActive = true
            iconView.bottomAnchor.constraint(equalTo: bottomAnchor).isActive = true
            iconView.translatesAutoresizingMaskIntoConstraints = false
        case .preview:
            linkPreview = LinkPreview.create()
            addSubview(linkPreview)
            linkPreview.centerXAnchor.constraint(equalTo: centerXAnchor).isActive = true
            linkPreview.topAnchor.constraint(equalTo: topAnchor, constant: 10).isActive = true
            linkPreview.widthAnchor.constraint(equalTo: widthAnchor, multiplier: 0.8).isActive = true
            linkPreview.heightAnchor.constraint(equalTo: heightAnchor, multiplier: 0.8).isActive = true
            linkPreview.translatesAutoresizingMaskIntoConstraints = false
        }
        
        loadContentIntoView(contentType: contentType)
    }
    
    private func loadContentIntoView(contentType: ContentType) {
        switch contentType {
        case .icon:
            iconView.linkIcon.isHidden = albumsView
            
            if let previewImageURL = media.previewImage?.url,
                let filePath = previewImageURL.path {
                // TODO: Loading needs to be async
                iconView?.image.image = UIImage(contentsOfFile: filePath)
            }
            else {
                // No image; reset it so we don't have a lingering other image.
                iconView?.image.image = nil
            }

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
            linkPreview.setup(with: linkData)
            linkPreview.textAndIconAction = {[weak self] in
                guard let self = self else {
                    return
                }
                self.linkTapAction?(contents.url)
            }
        }
    }
    
    func setupWith(media: URLMediaObject, albumsView: Bool) {
        self.media = media
        backgroundColor = .white
        createContentViewIfNeeded()
        self.albumsView = albumsView
    }
    
    func showWith(size: CGSize) {
    }
    
    func changeToFullsizedMediaForZooming() {
    }
}
