//
//  ImageCollectionVC.swift
//  SharedImages
//
//  Created by Christopher Prince on 3/10/17.
//  Copyright © 2017 Spastic Muffin, LLC. All rights reserved.
//

import Foundation
import UIKit
import SMCoreLib

protocol LargeImageCellDelegate {
    func cellZoomed(cell: ImageCollectionVC, toZoomSize zoomSize:CGSize, withOriginalSize originalSize:CGSize)
}

class ImageCollectionVC : UICollectionViewCell {
    // For large images only, the imageView's are embedded in a scroll view to enable pinch/zoom. Because these only apply to large images, referenced as scrollView? below.
    @IBOutlet weak var scrollView: UIScrollView!
    
    // Also only applies to large scale images, because will only be used when scroll view is used.
    fileprivate var switchedToFullScaleImageForZooming = false

    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var title: UILabel!
    private(set) var image:Image!
    private(set) weak var syncController:SyncController!
    weak var imageCache:LRUCache<Image>!
    
    var delegate:LargeImageCellDelegate!
    var originalSize:CGSize!

    required public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        switchedToFullScaleImageForZooming = false
    }
    
    func setProperties(image:Image, syncController:SyncController, cache: LRUCache<Image>) {
        self.image = image

        self.syncController = syncController
        title.text = image.title
        imageCache = cache
        
        scrollView?.zoomScale = 1.0
        scrollView?.maximumZoomScale = 6.0
        scrollView?.delegate = self
    }
    
    // I had problems knowing when the cell was sized correctly so that I could call `ImageStorage.getImage`. `layoutSubviews` seems to not be the right place. And neither is `setProperties` (which gets called by cellForItemAt). When the UICollectionView is first displayed, I get small sizes (less than 1/2 of correct sizes) at least on iPad. Odd.
    func cellSizeHasBeenChanged() {
        // For some reason, when I get here, the cell is sized correctly, but it's subviews are not. And more specifically, the image view subview is not sized correctly all the time. And since I'm basing my image fetch/resize on the image view size, I need it correctly sized right now.
        layoutIfNeeded()
        
        scrollView?.contentSize = imageView.frame.size
        
        let smallerSize = ImageExtras.boundingImageSizeFor(originalSize: image.originalSize, boundingSize: imageView.frameSize)
        imageView.image = imageCache.getItem(from: image, with: smallerSize)
        
        originalSize = smallerSize
    }
    
    func remove() {
        // The sync/remote remove must happen before the local remove-- or we lose the reference!
        syncController.remove(image: image)
        
        CoreData.sessionNamed(CoreDataExtras.sessionName).remove(image)
        CoreData.sessionNamed(CoreDataExtras.sessionName).saveContext()
    }
}

extension ImageCollectionVC : UIScrollViewDelegate {
    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        return imageView
    }
    
    func scrollViewDidZoom(_ scrollView: UIScrollView) {
        delegate.cellZoomed(cell: self, toZoomSize: imageView.frame.size, withOriginalSize: originalSize)
        //Log.msg("imageView.frame.size: \(imageView.frame.size)")
        
        if !switchedToFullScaleImageForZooming {
            switchedToFullScaleImageForZooming = true
            
            // Load the full scale image to give the user better resolution when zooming in.
            let uiImage = ImageExtras.fullSizedImage(url: image.url! as URL)
            imageView.image = uiImage
        }
    }
}


