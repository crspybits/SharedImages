//
//  LargeImages.swift
//  SharedImages
//
//  Created by Christopher Prince on 4/21/17.
//  Copyright © 2017 Spastic Muffin, LLC. All rights reserved.
//

import Foundation
import SMCoreLib

// http://stackoverflow.com/questions/18087073/start-uicollectionview-at-a-specific-indexpath

class LargeImages : UIViewController {
    // Set these two when creating an instance of this class.
    var startItem: Int! = 0
    weak var syncController:SyncController?
    
    private var seekToIndexPath:IndexPath?
    let IMAGE_WIDTH_PADDING:CGFloat = 20.0

    @IBOutlet weak var collectionView: UICollectionView!
    var coreDataSource:CoreDataSource!
    let reuseIdentifier = "largeImage"
    
    typealias FirstTimeZoomed = Bool
    var zoomedCells = [IndexPath: FirstTimeZoomed]()
    
    fileprivate var imageCache:LRUCache<Image>! {
        return ImageExtras.imageCache
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        collectionView.dataSource = self
        collectionView.delegate = self

        coreDataSource = CoreDataSource(delegate: self)
        edgesForExtendedLayout = []
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        ImageExtras.resetToSmallerImageCache() {
            collectionView.reloadData()
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        coreDataSource.fetchData()

        let indexPath = IndexPath(item: startItem, section: 0)
        seekToIndexPath = indexPath
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // 12/27/17; This is overkill, but up until today: a) I had a memory leak where this LargeImages VC was being retained, and b) this was causing a crash when images were deleted. So, I'm going to make darn sure the path to that crash is no longer possible.
        coreDataSource = nil
    }
    
    deinit {
        Log.msg("deinit")
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        
        // Because the order of indexPathsForVisibleItems doesn't appear sorted-- otherwise, with repeated device rotation, we get to much image motion. Looks odd.
        let visibleItems = collectionView.indexPathsForVisibleItems as [IndexPath]
        let sortedArray = visibleItems.sorted {$0 < $1}
        
        seekToIndexPath = sortedArray[0]
        
        // I get some odd effects if I retain zooming across the rotation-- cells show up as being empty.
        zoomedCells.removeAll()
        
        // This is my solution to an annoying problem: I need to reload the images at their changed size after rotation. This is how I'm getting a callback *after* the rotation has completed when the cells have been sized properly.
        coordinator.animate(alongsideTransition: nil) { context in
            self.collectionView.reloadData()
        }
    }
    
    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()

        // To resize cells when we rotate the device or first enter into this view controller.
        if seekToIndexPath != nil {
            invalidateLayout()
        }
    }
    
    func invalidateLayout(withAnimation animation: Bool = false) {
        if let flowLayout = collectionView.collectionViewLayout as? UICollectionViewFlowLayout {
            if animation {
                collectionView.performBatchUpdates({
                    flowLayout.invalidateLayout()
                }, completion: nil)
                }
            else {
                flowLayout.invalidateLayout()
            }
        }
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        // 12/26/17; Adding the DispatchQueue call to cure: https://github.com/crspybits/SharedImages/issues/58
        DispatchQueue.main.async {[unowned self] in
            // Because when we rotate the device, we don't end up looking at the same image. I first tried this at the end of `viewWillLayoutSubviews`, but it doesn't work there.
            if self.seekToIndexPath != nil {
                self.collectionView.scrollToItem(at: self.seekToIndexPath!, at: .left, animated: false)
                self.seekToIndexPath = nil
            }
        }
    }
}

extension LargeImages : CoreDataSourceDelegate {
    // This must have sort descriptor(s) because that is required by the NSFetchedResultsController, which is used internally by this class.
    func coreDataSourceFetchRequest(_ cds: CoreDataSource!) -> NSFetchRequest<NSFetchRequestResult>! {
        let ascending = ImageExtras.currentSortingOrder.stringValue == SortingOrder.newerAtBottom.rawValue
        return Image.fetchRequestForAllObjects(ascending:ascending)
    }
    
    func coreDataSourceContext(_ cds: CoreDataSource!) -> NSManagedObjectContext! {
        return CoreData.sessionNamed(CoreDataExtras.sessionName).context
    }
    
    // Should return YES iff the context save was successful.
    func coreDataSourceSaveContext(_ cds: CoreDataSource!) -> Bool {
        return CoreData.sessionNamed(CoreDataExtras.sessionName).saveContext()
    }
    
    func coreDataSource(_ cds: CoreDataSource!, objectWasDeleted indexPathOfDeletedObject: IndexPath!) {
    
        // 8/24/17; Looks like this is where the crash happens.
        collectionView.deleteItems(at: [indexPathOfDeletedObject as IndexPath])
        Log.msg("LargeImages: objectWasDeleted")
    }
    
    func coreDataSource(_ cds: CoreDataSource!, objectWasUpdated indexPathOfUpdatedObject: IndexPath!) {
        collectionView.reloadData()
    }
    
    // 5/20/16; Odd. This gets called when an object is updated, sometimes. It may be because the sorting key I'm using in the fetched results controller changed.
    func coreDataSource(_ cds: CoreDataSource!, objectWasMovedFrom oldIndexPath: IndexPath!, to newIndexPath: IndexPath!) {
        collectionView.reloadData()
    }
}

// MARK: UICollectionViewDelegate
extension LargeImages : UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
    
        let cell = cell as! ImageCollectionVC
        cell.cellSizeHasBeenChanged()
        cell.delegate = self
    }
    
    func collectionView(_ collectionView: UICollectionView, didEndDisplaying cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
    
        if zoomedCells[indexPath] != nil {
            // When we come back to a zoomed cell after it goes out of sight, we want it to be back to normal.
            zoomedCells.removeValue(forKey: indexPath)
            invalidateLayout(withAnimation: true)
        }
    }
}

// MARK: UICollectionViewDataSource
extension LargeImages : UICollectionViewDataSource {
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return Int(coreDataSource.numberOfRows(inSection: 0))
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: reuseIdentifier, for: indexPath) as! ImageCollectionVC
        
        if let syncController = syncController {
            cell.setProperties(image: self.coreDataSource.object(at: indexPath) as! Image, syncController: syncController, cache: imageCache)
        }
        
        return cell
    }
}

// MARK: UICollectionViewDelegateFlowLayout
extension LargeImages : UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
    
        // Because we can scroll horizontally, let the width be large
        let maxWidth = max(collectionView.frame.height, collectionView.frame.width)
        let boundingCellSize = CGSize(width: maxWidth, height: collectionView.frame.height)
        
        let image = self.coreDataSource.object(at: indexPath) as! Image
        var boundedImageSize = ImageExtras.boundingImageSizeFor(originalSize: image.originalSize, boundingSize: boundingCellSize)
        
        if let firstTimeZoomed = zoomedCells[indexPath], firstTimeZoomed {
            // I first tried zooming the item size along with the image. That didn't work very well, oddly enough. I get the item size growing far too large. Instead, what works better, is the first time I get zooming, just expand out the size of the item.
            boundedImageSize.width = maxWidth
            boundedImageSize.height = collectionView.frame.height
        }
        
        return CGSize(width: boundedImageSize.width + IMAGE_WIDTH_PADDING, height: boundedImageSize.height + ImageCollectionVC.largeTitleHeight)
    }
}

extension LargeImages : LargeImageCellDelegate {
    func cellZoomed(cell: ImageCollectionVC, toZoomSize zoomSize:CGSize, withOriginalSize originalSize:CGSize) {
    
        if let indexPath = collectionView.indexPath(for: cell) {
            // Don't let the cell shrink too small-- get odd effects here. The cell can get so small it shrinks out of sight. Don't know why that is. I thought the minimum scaling I put in the collection view cell would handle it.
            if zoomSize.width > originalSize.width && zoomSize.height > originalSize.height {
                if zoomedCells[indexPath] == nil {
                    // This is the first attempt to make the cell larger.
                    zoomedCells[indexPath] = true
                    invalidateLayout(withAnimation: true)
                }
                else {
                    zoomedCells[indexPath] = false
                }
            }
            else {
                if zoomedCells[indexPath] != nil {
                    // The cell has gone back to it's original size-- let's go back to the `sizeForItemAt` we were using originally for it.
                    zoomedCells.removeValue(forKey: indexPath)
                    invalidateLayout(withAnimation: true)
                }
            }
        }
    }
}
