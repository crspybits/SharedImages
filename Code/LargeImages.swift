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
    var syncController:SyncController!
    
    private var seekToIndexPath:IndexPath?
    let IMAGE_WIDTH_PADDING:CGFloat = 20.0

    @IBOutlet weak var collectionView: UICollectionView!
    var coreDataSource:CoreDataSource!
    let reuseIdentifier = "largeImage"
    
    fileprivate var imageCache:LRUCache<Image>! {
        return ImageExtras.imageCache
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        collectionView.dataSource = self
        collectionView.delegate = self

        coreDataSource = CoreDataSource(delegate: self)
        self.edgesForExtendedLayout = []
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
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        
        // Because the order of indexPathsForVisibleItems doesn't appear sorted-- otherwise, with repeated device rotation, we get to much image motion. Looks odd.
        let visibleItems = collectionView.indexPathsForVisibleItems as [IndexPath]
        let sortedArray = visibleItems.sorted {$0 < $1}
        
        seekToIndexPath = sortedArray[0]
        
        // This is my solution to an annoying problem: I need to reload the images at their changed size after rotation. This is how I'm getting a callback *after* the rotation has completed when the cells have been sized properly.
        coordinator.animate(alongsideTransition: nil) { context in
            self.collectionView.reloadData()
        }
    }
    
    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()

        // To resize cells when we rotate the device or first enter into this view controller.
        if seekToIndexPath != nil {
            if let flowLayout = collectionView.collectionViewLayout as? UICollectionViewFlowLayout {
                flowLayout.invalidateLayout()
            }
        }
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        // Because when we rotate the device, we don't end up looking at the same image. I first tried this at the end of `viewWillLayoutSubviews`, but it doesn't work there.
        if seekToIndexPath != nil {
            collectionView.scrollToItem(at: seekToIndexPath!, at: .left, animated: false)
            seekToIndexPath = nil
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
        collectionView.deleteItems(at: [indexPathOfDeletedObject as IndexPath])
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
        (cell as! ImageCollectionVC).cellSizeHasBeenChanged()
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
        cell.setProperties(image: self.coreDataSource.object(at: indexPath) as! Image, syncController: syncController, cache: imageCache)
        
        return cell
    }
}

// MARK: UICollectionViewDelegateFlowLayout
extension LargeImages : UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
    
        // Because we can scroll horizontally, let the width be large
        let width = max(collectionView.frame.height, collectionView.frame.width)
        let boundingCellSize = CGSize(width: width, height: collectionView.frame.height)
        
        let image = self.coreDataSource.object(at: indexPath) as! Image
        let boundedImageSize = ImageExtras.boundingImageSizeFor(originalSize: image.originalSize, boundingSize: boundingCellSize)

        return CGSize(width: boundedImageSize.width + IMAGE_WIDTH_PADDING, height: boundedImageSize.height)
    }
}
