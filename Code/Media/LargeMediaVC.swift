//
//  LargeMediaVC.swift
//  SharedImages
//
//  Created by Christopher Prince on 4/21/17.
//  Copyright © 2017 Spastic Muffin, LLC. All rights reserved.
//

import Foundation
import SMCoreLib
import SyncServer

// http://stackoverflow.com/questions/18087073/start-uicollectionview-at-a-specific-indexpath

class LargeMediaVC : UIViewController {
    // Set these when creating an instance of this class.
    
    // This is a media object instead of an index, because the IndexPath's vary from the small media screen to the large media screen-- the large media screen doesn't display media with errors.
    var startMedia: FileMediaObject?
    
    weak var mediaHandler:MediaHandler?
    var sharingGroup: SyncServer.SharingGroup!
    
    private var seekToIndexPath:IndexPath?
    let IMAGE_WIDTH_PADDING:CGFloat = 20.0

    @IBOutlet weak var collectionView: UICollectionView!
    
    private var _coreDataSource:CoreDataSource!
    private var coreDataSource:CoreDataSource! {
        get {
            if _coreDataSource == nil {
                // 12/31/17; Just had a crash here. On `coreDataSource.fetchData()`. This was arising because of the nil assignment I put in `viewWillDisappear`. I'm putting the assignment to `coreDataSource` here (moved from viewDidLoad) to deal with this.
                // 2/13/18; Trying to fix: https://github.com/crspybits/SharedImages/issues/80
                _coreDataSource = CoreDataSource(delegate: self)
                _coreDataSource.fetchData()
                
                seekToIndexPath = nil
                if let startMedia = startMedia,
                    let indexPath = _coreDataSource.indexPath(for: startMedia) {
                    seekToIndexPath = indexPath
                }
            }
            
            return _coreDataSource
        }
        
        set {
            _coreDataSource = newValue
        }
    }
    
    let reuseIdentifier = "largeImage"
    
    typealias FirstTimeZoomed = Bool
    var zoomedCells = [IndexPath: FirstTimeZoomed]()
    
    fileprivate var imageCache:LRUCache<ImageMediaObject>! {
        return ImageExtras.imageCache
    }
    
    static func create() -> LargeMediaVC {
        return UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "LargeMediaVC") as! LargeMediaVC
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        collectionView.dataSource = self
        collectionView.delegate = self
        
        let backButton = UIBarButtonItem(image: #imageLiteral(resourceName: "back"), style: .plain, target: self, action: #selector(backAction))
        navigationItem.leftBarButtonItem = backButton
    }
    
    @objc private func backAction() {
        navigationController?.popViewController(animated: true)
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        ImageExtras.resetToSmallerImageCache() {
            collectionView?.reloadData()
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // 12/27/17; This is overkill, but up until today: a) I had a memory leak where this LargeImages VC was being retained, and b) this was causing a crash when images were deleted. So, I'm going to make darn sure the path to that crash is no longer possible.
        coreDataSource = nil
    }
    
    deinit {
        Log.info("deinit")
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        
        // Because the order of indexPathsForVisibleItems doesn't appear sorted-- otherwise, with repeated device rotation, we get too much image motion. Looks odd.
        if let collectionView = collectionView {
            let visibleItems = collectionView.indexPathsForVisibleItems as [IndexPath]
            let sortedArray = visibleItems.sorted {$0 < $1}
            
            // When the discussion thread screen is open, and the device is rotated, we can get a crash without this test.
            guard sortedArray.count > 0 else {
                return
            }
            
            seekToIndexPath = sortedArray[0]
            // I get some odd effects if I retain zooming across the rotation-- cells show up as being empty.
            zoomedCells.removeAll()
            
            // This is my solution to an annoying problem: I need to reload the images at their changed size after rotation. This is how I'm getting a callback *after* the rotation has completed when the cells have been sized properly.
            coordinator.animate(alongsideTransition: nil) { context in
                collectionView.reloadData()
            }
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
        if let flowLayout = collectionView?.collectionViewLayout as? UICollectionViewFlowLayout {
            if animation {
                // 4/15/18: Crash in here. Perhaps related to recent crashes such as https://github.com/crspybits/SharedImages/issues/100 (Just added `?`).
                collectionView?.performBatchUpdates({
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
        
        // Without the `isVisible` test, when user is on a discussion thread, and device rotates, can come back to large images, may not end up back on the same large image as when you started.
        if isVisible() {
            // 12/26/17; Adding the DispatchQueue call to cure: https://github.com/crspybits/SharedImages/issues/58
            DispatchQueue.main.async {[unowned self] in
                // Because when we rotate the device, we don't end up looking at the same image. I first tried this at the end of `viewWillLayoutSubviews`, but it doesn't work there.
                if let indexPath = self.seekToIndexPath {
                    Log.info("self.seekToIndexPath: \(String(describing: indexPath))")
                    self.collectionView?.scrollToItem(at: indexPath, at: .left, animated: false)
                    self.seekToIndexPath = nil
                }
            }
        }
    }
    
    // See https://stackoverflow.com/questions/2777438/how-to-tell-if-uiviewcontrollers-view-is-visible
    private func isVisible() -> Bool {
        return isViewLoaded && self.view.window != nil && parent != nil
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        Progress.session.viewController = self
    }
}

extension LargeMediaVC : CoreDataSourceDelegate {
    // This must have sort descriptor(s) because that is required by the NSFetchedResultsController, which is used internally by this class.
    func coreDataSourceFetchRequest(_ cds: CoreDataSource!) -> NSFetchRequest<NSFetchRequestResult>! {
        let params = FileMediaObject.SortFilterParams(sortingOrder: Parameters.sortingOrder, isAscending: Parameters.sortingOrderIsAscending, unreadCounts: Parameters.unreadCounts, sharingGroupUUID: sharingGroup.sharingGroupUUID, includeErrors: false)
        return FileMediaObject.fetchRequestForAllObjects(params: params)
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
        collectionView?.deleteItems(at: [indexPathOfDeletedObject as IndexPath])
        Log.info("LargeImages: objectWasDeleted")
    }
    
    func coreDataSource(_ cds: CoreDataSource!, objectWasUpdated indexPathOfUpdatedObject: IndexPath!) {
        collectionView?.reloadData()
    }
    
    // 5/20/16; Odd. This gets called when an object is updated, sometimes. It may be because the sorting key I'm using in the fetched results controller changed.
    func coreDataSource(_ cds: CoreDataSource!, objectWasMovedFrom oldIndexPath: IndexPath!, to newIndexPath: IndexPath!) {
        collectionView?.reloadData()
    }
}

// MARK: UICollectionViewDelegate
extension LargeMediaVC : UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
    
        let cell = cell as! MediaCollectionViewCell
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
extension LargeMediaVC : UICollectionViewDataSource {
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return Int(coreDataSource.numberOfRows(inSection: 0))
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: reuseIdentifier, for: indexPath) as! MediaCollectionViewCell
        
        if let syncController = mediaHandler?.syncController,
            let media = self.coreDataSource.object(at: indexPath) as? FileMediaObject {
            cell.setProperties(media: media, syncController: syncController, cache: imageCache, imageTapBehavior: { [unowned self] in
                self.showDiscussionIfPresent(media: media)
            })
        }
        
        return cell
    }
    
    func showDiscussionIfPresent(media: FileMediaObject) {
        guard let discussion = media.discussion else {
            return
        }
        
        let discussionModal = DiscussionVC()
        discussionModal.show(fromParentVC: self, discussion:discussion, delegate: self) { [unowned self] in
            // To clear the unread count.
            self.collectionView?.reloadData()
        }
    }
}

// MARK: UICollectionViewDelegateFlowLayout
extension LargeMediaVC : UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
    
        // Because we can scroll horizontally, let the width be large
        let maxWidth = max(collectionView.frame.height, collectionView.frame.width)
        let boundingCellSize = CGSize(width: maxWidth, height: collectionView.frame.height)
        
        /* 2/13/18; Looks like this line caused a crash: https://github.com/crspybits/SharedImages/issues/80
        I assume this must have occurred with an unwrapping of `coreDataSource` when it was nil. I'm trying to fix this by using a getter which always sets the coreDataSource if nil.
        */
        let image = self.coreDataSource.object(at: indexPath) as! ImageMediaObject
        
        guard !image.hasError, let imageOriginalSize = image.originalSize else {
            return CGSize(width: boundingCellSize.width + IMAGE_WIDTH_PADDING, height: boundingCellSize.height + MediaCollectionViewCell.largeTitleHeight)
        }
        
        var boundedImageSize = ImageExtras.boundingImageSizeFor(originalSize: imageOriginalSize, boundingSize: boundingCellSize)
        
        if let firstTimeZoomed = zoomedCells[indexPath], firstTimeZoomed {
            // I first tried zooming the item size along with the image. That didn't work very well, oddly enough. I get the item size growing far too large. Instead, what works better, is the first time I get zooming, just expand out the size of the item.
            boundedImageSize.width = maxWidth
            boundedImageSize.height = collectionView.frame.height
        }
        
        return CGSize(width: boundedImageSize.width + IMAGE_WIDTH_PADDING, height: boundedImageSize.height + MediaCollectionViewCell.largeTitleHeight)
    }
}

extension LargeMediaVC : LargeMediaCellDelegate {
    func cellZoomed(cell: MediaCollectionViewCell, toZoomSize zoomSize:CGSize, withOriginalSize originalSize:CGSize) {
    
        if let indexPath = collectionView?.indexPath(for: cell) {
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

extension LargeMediaVC : DiscussionVCDelegate {
    func discussionVCWillClose(_ vc: DiscussionVC) {
        Progress.session.viewController = self
    }
    
    func discussionVC(_ vc: DiscussionVC, changedDiscussion:DiscussionFileObject) {
        mediaHandler?.syncController.update(discussion: changedDiscussion)
    }
    
    func discussionVC(_ vc: DiscussionVC, resetUnreadCount:DiscussionFileObject) {
        collectionView?.reloadData()
    }
    
    func discussionVC(_ vc: DiscussionVC, discussion:DiscussionFileObject, refreshWithCompletion: (()->())?) {
        do {
            try mediaHandler?.syncController.sync(sharingGroupUUID: discussion.sharingGroupUUID!) {
                // If you receive discussion messages for a thread, and are *in* that discussion-- i.e., you are using the "refresh"-- mark that unread count as 0. Literally, we've read any new content-- so don't need the reminder.
                discussion.unreadCount = 0
                discussion.save()
                
                refreshWithCompletion?()
            }
        } catch (let error) {
            SMCoreLib.Alert.show(fromVC: self, withTitle: "Could not sync", message: "\(error)")
        }
    }
}
