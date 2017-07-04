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

class ImageCollectionVC : UICollectionViewCell {
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var title: UILabel!
    private(set) var image:Image!
    private(set) weak var syncController:SyncController!
    weak var imageCache:LRUCache<Image>!

    required public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    func setProperties(image:Image, syncController:SyncController, cache: LRUCache<Image>) {
        self.image = image
        self.syncController = syncController
        title.text = image.title
        imageCache = cache
    }
    
    // I had problems knowing when the cell was sized correctly so that I could call `ImageStorage.getImage`. `layoutSubviews` seems to not be the right place. And neither is `setProperties` (which gets called by cellForItemAt). When the UICollectionView is first displayed, I get small sizes (less than 1/2 of correct sizes) at least on iPad. Odd.
    func cellSizeHasBeenChanged() {
        // For some reason, when I get here, the cell is sized correctly, but it's subviews are not. And more specifically, the image view subview is not sized correctly all the time. And since I'm basing my image fetch/resize on the image view size, I need it correctly sized right now.
        layoutIfNeeded()
        
        let smallerSize = ImageExtras.boundingImageSizeFor(originalSize: image.originalSize, boundingSize: imageView.frameSize)
        imageView.image = imageCache.getItem(from: image, with: smallerSize)
    }
    
    func remove() {
        // The sync/remote remove must happen before the local remove-- or we lose the reference!
        syncController.remove(image: image)
        
        CoreData.sessionNamed(CoreDataExtras.sessionName).remove(image)
        CoreData.sessionNamed(CoreDataExtras.sessionName).saveContext()
    }
}

