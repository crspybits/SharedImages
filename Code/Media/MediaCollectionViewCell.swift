//
//  MediaCollectionViewCell.swift
//  SharedImages
//
//  Created by Christopher Prince on 3/10/17.
//  Copyright © 2017 Spastic Muffin, LLC. All rights reserved.
//

import Foundation
import UIKit
import SMCoreLib
import BadgeSwift
import SMLinkPreview

protocol LargeMediaCellDelegate : class {
    func cellZoomed(cell: MediaCollectionViewCell, toZoomSize zoomSize:CGSize, withOriginalSize originalSize:CGSize)
}

class MediaCollectionViewCell : UICollectionViewCell {
    // For large images only, the mediaView's are embedded in a scroll view to enable pinch/zoom. Because these only apply to large images, referenced as scrollView? below.
    @IBOutlet weak var scrollView: UIScrollView!
    
    // Also only applies to large scale images, because will only be used when scroll view is used.
    fileprivate var switchedToFullScaleImageForZooming = false

    @IBOutlet weak var mediaViewContainer: MediaViewContainer!
    var mediaView: MediaView!
    
    // These are oversized to give space for padding.
    static let smallTitleHeight:CGFloat = 15
    static let largeTitleHeight:CGFloat = 25
    
    @IBOutlet weak var title: UILabel!
    
    // These two are only in small image VC.
    @IBOutlet weak var errorImageView: UIImageView!
    @IBOutlet weak var selectedIcon: UIImageView!
    
    private(set) var media:MediaType!
    private(set) weak var syncController:SyncController!
    weak var imageCache:LRUCache<ImageMediaObject>?
    
    weak var delegate:LargeMediaCellDelegate?
    var originalSize:CGSize!
    let badge = BadgeSwift()
    var tapGesture: UITapGestureRecognizer?
    var imageTapBehavior:(()->())?
    
    // Only for small media.
    enum SelectedState {
        case notSelected
        case selected
    }
    var selectedState: SelectedState? {
        didSet {
            switch self.selectedState {
            case .none:
                break
            case .some(.selected), .some(.notSelected):
                self.selectedIcon?.isHidden = false
            }
            
            UIView.animate(withDuration: 0.2, animations: {[unowned self] in
                switch self.selectedState {
                case .none:
                    self.selectedIcon?.alpha = 0
                    self.mediaViewContainer.alpha = 1
                case .some(.selected):
                    self.selectedIcon?.alpha = 1
                    self.mediaViewContainer.alpha = 1
                case .some(.notSelected):
                    self.selectedIcon?.alpha = 0.5
                    self.mediaViewContainer.alpha = 0.8
                }
            }, completion: { _ in
                switch self.selectedState {
                case .none:
                    self.selectedIcon?.isHidden = true
                case .some(.selected), .some(.notSelected):
                    break
                }
            })
        }
    }

    required public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        switchedToFullScaleImageForZooming = false
        selectedState = nil
        badge.removeFromSuperview()
    }
    
    func setProperties(media:MediaType, syncController:SyncController, cache: LRUCache<ImageMediaObject>, imageTapBehavior:(()->())? = nil) {
        selectedState = nil
        self.media = media
        self.syncController = syncController
        title.text = media.title
        imageCache = cache
        
        switch media {
        case is ImageMediaObject:
            let imageView:ImageMediaView
            if let imv = mediaViewContainer.mediaView as? ImageMediaView {
                imageView = imv
            }
            else {
                imageView = ImageMediaView()
                mediaViewContainer.mediaView = imageView
            }
            
            if let imageCache = imageCache {
                imageView.setupWith(media: media as! ImageMediaObject, imageCache: imageCache)
            }
            self.mediaView = imageView
            
        case is URLMediaObject:
            let urlView:URLMediaView
            if let umv = mediaViewContainer.mediaView as? URLMediaView {
                urlView = umv
            }
            else {
                urlView = URLMediaView()
                mediaViewContainer.mediaView = urlView
            }
            
            urlView.setupWith(media: media as! URLMediaObject)
            self.mediaView = urlView
            
        default:
            assert(false)
        }
        
        if let _ = errorImageView {
            var showError = false
            if let _ = self.media.url {
                if self.media.eitherHasError {
                    showError = true
                }
            }
            else if self.media.eitherHasError {
                showError = true
                
                // No url, and thus no contents on the media view -- it looks odd if there is no color/image on the media view. Give it some color.
                mediaViewContainer.backgroundColor = .lightGray
            }
            
            errorImageView?.isHidden = !showError
        }

        scrollView?.zoomScale = 1.0
        scrollView?.maximumZoomScale = 6.0
        scrollView?.delegate = self
        
        self.imageTapBehavior = imageTapBehavior

        if let discussion = media.discussion {
            // Color from http://www.tayloredmktg.com/rgb/
            title.textColor = UIColor(red: 30.0/255.0, green: 144.0/255.0, blue: 255.0/255.0, alpha: 1.0)
            
            if let _ = imageTapBehavior, tapGesture == nil {
                tapGesture = UITapGestureRecognizer(target: self, action: #selector(tapGestureAction))
                
                // Putting this on the scrollView and not the mediaView because the tap is not recognized if I put it on the mediaView.
                scrollView?.addGestureRecognizer(tapGesture!)
            }

            if discussion.unreadCount > 0 {
                badge.format(withUnreadCount: Int(discussion.unreadCount))
                mediaViewContainer.addSubview(badge)
            }
        }
        else {
            title.textColor = UIColor.black
        }
    }
    
    @objc private func tapGestureAction() {
        // Don't need to check for an error here, because this only happens with large images and we won't get that far if there is an error.
        imageTapBehavior?()
    }
    
    // I had problems knowing when the cell was sized correctly so that I could call `ImageStorage.getImage`. `layoutSubviews` seems to not be the right place. And neither is `setProperties` (which gets called by cellForItemAt). When the UICollectionView is first displayed, I get small sizes (less than 1/2 of correct sizes) at least on iPad. Odd.
    func cellSizeHasBeenChanged() {
        // For some reason, when I get here, the cell is sized correctly, but it's subviews are not. And more specifically, the image view subview is not sized correctly all the time. And since I'm basing my media fetch/resize on the media view size, I need it correctly sized right now.
        layoutIfNeeded()
        
        // 8/29/17; In some edge cases, the `mediaViewContainer.frame.size` can have a dimension that is too small-- e.g., 0 for height. This can happen with a really wide image that is short.
        let minimumMediaDimension:CGFloat = 15
        var size = mediaViewContainer.frame.size
        size.height = max(size.height, minimumMediaDimension)
        size.width = max(size.width, minimumMediaDimension)
        mediaViewContainer.frameSize = size
        
        scrollView?.contentSize = size

        // Don't use media.hasError here only because on an upload/gone case, we do have a valid URL and can render the media.
        guard let mediaOriginalSize = media.originalSize else {
            originalSize = size
            return
        }
        
        let smallerSize = ImageExtras.boundingImageSizeFor(originalSize: mediaOriginalSize, boundingSize: size)
        
        mediaView.showWith(size: smallerSize)

        originalSize = smallerSize
    }
}

extension MediaCollectionViewCell : UIScrollViewDelegate {
    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        return mediaViewContainer
    }
    
    func scrollViewDidZoom(_ scrollView: UIScrollView) {
        delegate?.cellZoomed(cell: self, toZoomSize: mediaViewContainer.frame.size, withOriginalSize: originalSize)
        
        if !switchedToFullScaleImageForZooming {
            switchedToFullScaleImageForZooming = true

            // Load full scale media to give the user better resolution when zooming in.
            mediaView.changeToFullsizedMediaForZooming()
        }
    }
}
