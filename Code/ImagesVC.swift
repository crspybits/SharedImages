//
//  ImagesVC.swift
//  SharedImages
//
//  Created by Christopher Prince on 3/8/17.
//  Copyright © 2017 Spastic Muffin, LLC. All rights reserved.
//

import UIKit
import SMCoreLib
import SyncServer

class ImagesVC: UIViewController {
    let reuseIdentifier = "ImageIcon"
    var acquireImage:SMAcquireImage!
    var addImageBarButton:UIBarButtonItem!
    var sortingOrder:UIBarButtonItem!
    var coreDataSource:CoreDataSource!
    var syncController = SyncController()
    
    // To enable pulling down on the table view to do a sync with server.
    var refreshControl:ODRefreshControl!
    
    static let spinnerContainerSize:CGFloat = 25
    var spinnerContainer:UIView!
    let spinner = SyncSpinner(frame: CGRect(x: 0, y: 0, width: spinnerContainerSize, height: spinnerContainerSize))
    
    @IBOutlet weak var collectionView: UICollectionView!
    
    var timeThatSpinnerStarts:CFTimeInterval!
    
    fileprivate var imageCache:LRUCache<Image>! {
        return ImageExtras.imageCache
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        collectionView.dataSource = self
        collectionView.delegate = self
  
        // Spinner that shows when syncing
        createSpinnerContainer()
        spinnerContainer.addSubview(spinner)
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(spinnerTapGestureAction))
        self.spinner.addGestureRecognizer(tapGesture)
        
        // Adding images
        addImageBarButton = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(addImageAction))
        navigationItem.rightBarButtonItem = addImageBarButton
        setAddButtonState()
        
        acquireImage = SMAcquireImage(withParentViewController: self)
        acquireImage.delegate = self
        
        coreDataSource = CoreDataSource(delegate: self)
        syncController.delegate = self
        
        // To manually refresh-- pull down on collection view.
        refreshControl = ODRefreshControl(in: collectionView)
        
        // A bit of a hack because the refresh control was appearing too high
        refreshControl.yOffset = -(navigationController!.navigationBar.frameHeight + UIApplication.shared.statusBarFrame.height)
        
        // I like the "tear drop" pull down, but don't want the activity indicator.
        refreshControl.activityIndicatorViewColor = UIColor.clear
        
        refreshControl.addTarget(self, action: #selector(refresh), for: .valueChanged)
        
        // Long press on image to delete.
        collectionView.alwaysBounceVertical = true
        let imageDeletionLongPress = UILongPressGestureRecognizer(target: self, action: #selector(imageDeletionLongPressAction(gesture:)))
        imageDeletionLongPress.delaysTouchesBegan = true
        collectionView?.addGestureRecognizer(imageDeletionLongPress)
        collectionView?.delegate = self
        
        // A label and a means to do a consistency check.
        let titleLabel = UILabel()
        titleLabel.text = "Shared Images"
        titleLabel.sizeToFit()
        navigationItem.titleView = titleLabel
        let lp = UILongPressGestureRecognizer(target: self, action: #selector(consistencyCheckAction(gesture:)))
        titleLabel.addGestureRecognizer(lp)
        titleLabel.isUserInteractionEnabled = true
        
        // Controlling sorting order of images
        sortingOrder = UIBarButtonItem(title: "Sort", style: .plain, target: self, action: #selector(sortingOrderAction))
        navigationItem.leftBarButtonItem = sortingOrder
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        ImageExtras.resetToSmallerImageCache() {
            collectionView.reloadData()
        }
    }
    
    func scrollIfNeeded(animated:Bool = true) {
        let count = collectionView.numberOfItems(inSection: 0)
        if count == 0 {
            return
        }
        
        var position:UICollectionViewScrollPosition
        var indexPath:IndexPath
        
        if ImageExtras.currentSortingOrder.stringValue == SortingOrder.newerAtTop.rawValue {
            indexPath = IndexPath(item: 0, section: 0)
            position = .bottom
        }
        else {
            indexPath = IndexPath(item: count-1, section: 0)
            position = .top
        }
        
        collectionView.scrollToItem(at: indexPath, at: position, animated: animated)
    }
    
    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()

        // To resize cells when we rotate the device.
        if let flowLayout = collectionView.collectionViewLayout as? UICollectionViewFlowLayout {
            flowLayout.invalidateLayout()
        }
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        
        // The collection view reload in the completion is my solution to an annoying problem: I need to reload the images at their changed size after rotation. This is how I'm getting a callback *after* the rotation has completed when the cells have been sized properly.
        coordinator.animate(alongsideTransition: {[unowned self] context in
            // Like below, can get here without having natigated to this tab!
            if self.spinnerContainer != nil {
                self.positionSpinnerContainer(usingScreenSize: UIScreen.main.bounds.size)
            }
        }) {[unowned self] context in
            // I made this an optional because, oddly, I can get in here when I've never navigated to this tab.
            self.collectionView?.reloadData()
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        coreDataSource.fetchData()
        positionSpinnerContainer(usingScreenSize: UIScreen.main.bounds.size)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        scrollIfNeeded(animated: true)

        AppBadge.checkForBadgeAuthorization(usingViewController: self)
        setAddButtonState()
    }
    
    func createSpinnerContainer() {
        spinnerContainer = UIView()
        spinnerContainer.backgroundColor = UIColor.clear
        spinnerContainer.frame = CGRect(x: 0, y: 0, width: ImagesVC.spinnerContainerSize, height: ImagesVC.spinnerContainerSize)
        self.tabBarController!.view.addSubview(spinnerContainer)
    }
    
    func positionSpinnerContainer(usingScreenSize size:CGSize) {
        var frame = spinnerContainer.frame
        
        // The - 5 is a fudge to get the spinner lined near the top of the tab bar graphics, so it looks about right.
        frame.origin.y = size.height - tabBarController!.tabBar.frame.height/2.0 - ImagesVC.spinnerContainerSize/2.0 - 5.0
        frame.origin.x = size.width/2.0 - ImagesVC.spinnerContainerSize/2.0
        
        spinnerContainer.frame = frame
    }

    func setAddButtonState() {
        switch SignInVC.sharingPermission {
        case .some(.admin), .some(.write), .none: // .none means this is not a sharing user.
            addImageBarButton?.isEnabled = true
            
        case .some(.read):
            addImageBarButton?.isEnabled = false
        }
    }
    
    @objc private func consistencyCheckAction(gesture : UILongPressGestureRecognizer!) {
        if gesture.state != .ended {
            return
        }
        
        let uuids = Image.fetchAll().map { $0.uuid! }
        SyncServer.session.consistencyCheck(localFiles: uuids, repair: false) { error in
        }
    }
    
    @objc private func imageDeletionLongPressAction(gesture : UILongPressGestureRecognizer!) {
        // Flash a red border around the image when the pressing starts-- to give an indication that something is going on.
        if gesture.state == .began {
            let p = gesture.location(in: self.collectionView)
            if let indexPath = collectionView.indexPathForItem(at: p) {
                let cell = self.collectionView.cellForItem(at: indexPath) as! ImageCollectionVC
                let layer = cell.layer
                layer.borderColor = UIColor.red.cgColor
                layer.borderWidth = 4.0
                cell.layoutIfNeeded()
                TimedCallback.withDuration(0.3) {
                    layer.borderColor = nil
                    layer.borderWidth = 0.0
                    cell.layoutIfNeeded()
                }
            }
        }
        if gesture.state != .ended {
            return
        }
        
        let p = gesture.location(in: self.collectionView)

        // Confirm the deletion with the user.
        
        if let indexPath = collectionView.indexPathForItem(at: p) {
            let cell = self.collectionView.cellForItem(at: indexPath) as! ImageCollectionVC
            
            var message:String?
            if cell.image.title != nil {
                message = "title: \(cell.image.title!)"
            }
            
            let alert = UIAlertController(title: "Remove this image?", message: message, preferredStyle: .actionSheet)
            alert.popoverPresentationController?.sourceView = cell
            Alert.styleForIPad(alert)
            
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) {alert in
            })
            alert.addAction(UIAlertAction(title: "Remove", style: .default) {alert in
                cell.remove()
            })
            self.present(alert, animated: true, completion: nil)
        } else {
            Log.msg("couldn't find index path")
        }
    }
    
    @objc private func refresh() {
        self.refreshControl.endRefreshing()
        syncController.sync()
    }
    
    // Enable a reset from error when needed.
    @objc private func spinnerTapGestureAction() {
        Log.msg("spinner tapped")
        refresh()
    }
    
    func addImageAction() {
        self.acquireImage.showAlert(fromBarButton: addImageBarButton)
    }
    
    func sortingOrderAction() {
        let alert = UIAlertController(title: "Sorting order of images:", message: "Newer images at the top or the bottom?", preferredStyle: .actionSheet)
        alert.popoverPresentationController?.barButtonItem = sortingOrder
        Alert.styleForIPad(alert)
        
        alert.addAction(UIAlertAction(title: "Newer at top", style: .default) {alert in
            if ImageExtras.currentSortingOrder.stringValue != SortingOrder.newerAtTop.rawValue {
                ImageExtras.currentSortingOrder.stringValue = SortingOrder.newerAtTop.rawValue
                self.coreDataSource.fetchData()
                self.collectionView.reloadData()
                self.scrollIfNeeded(animated:true)
            }
        })
        alert.addAction(UIAlertAction(title: "Newer at bottom", style: .default) {alert in
            if ImageExtras.currentSortingOrder.stringValue != SortingOrder.newerAtBottom.rawValue {
                ImageExtras.currentSortingOrder.stringValue = SortingOrder.newerAtBottom.rawValue
                self.coreDataSource.fetchData()
                self.collectionView.reloadData()
                self.scrollIfNeeded(animated:true)
            }
        })
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) {alert in
        })
        self.present(alert, animated: true, completion: nil)
    }
    
    @discardableResult
    func addLocalImage(newImageURL: SMRelativeLocalURL, mimeType:String, uuid:String? = nil, title:String? = nil, creationDate: NSDate? = nil) -> Image {
        var newImage:Image!
        
        if uuid == nil {
            newImage = Image.newObjectAndMakeUUID(makeUUID: true, creationDate: creationDate) as! Image
        }
        else {
            newImage = Image.newObjectAndMakeUUID(makeUUID: false, creationDate: creationDate) as! Image
            newImage.uuid = uuid
        }
        
        newImage.url = newImageURL
        newImage.mimeType = mimeType
        newImage.title = title
        
        let imageFileName = newImageURL.lastPathComponent
        let size = ImageStorage.size(ofImage: imageFileName, withPath: ImageExtras.largeImageDirectoryURL)
        newImage.originalHeight = Float(size.height)
        newImage.originalWidth = Float(size.width)

        CoreData.sessionNamed(CoreDataExtras.sessionName).saveContext()
        
        return newImage
    }
    
    func removeLocalImage(uuid:String) {
        ImageExtras.removeLocalImage(uuid:uuid)
    }
}

extension ImagesVC : UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let largeImages = storyboard!.instantiateViewController(withIdentifier: "LargeImages") as! LargeImages
        largeImages.startItem = indexPath.item
        largeImages.syncController = syncController
        navigationController!.pushViewController(largeImages, animated: true)
    }
    
    func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        (cell as! ImageCollectionVC).cellSizeHasBeenChanged()
        print("cell.frame: \(cell.frame)")
    }
}

// MARK: UICollectionViewDataSource
extension ImagesVC : UICollectionViewDataSource {
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

extension ImagesVC : SMAcquireImageDelegate {
    // Called before the image is acquired to obtain a URL for the image. A file shouldn't exist at this URL yet.
    func smAcquireImageURLForNewImage(_ acquireImage:SMAcquireImage) -> SMRelativeLocalURL {
        return FileExtras().newURLForImage()
    }
    
    // Called after the image is acquired.
    func smAcquireImage(_ acquireImage:SMAcquireImage, newImageURL: SMRelativeLocalURL, mimeType:String) {
    
        let userName = SignInManager.session.currentSignIn!.credentials!.username
        
        // We're making an image that the user of the app added-- we'll generate a new UUID.
        let newImage = addLocalImage(newImageURL:newImageURL, mimeType:mimeType, title:userName)
        
        scrollIfNeeded(animated:true)
        
        // Sync this new image with the server.
        syncController.add(image: newImage)
    }
}

extension ImagesVC : CoreDataSourceDelegate {
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
    
    func coreDataSource(_ cds: CoreDataSource!, objectWasInserted indexPathOfInsertedObject: IndexPath!) {
        collectionView.reloadData()
    }
    
    func coreDataSource(_ cds: CoreDataSource!, objectWasUpdated indexPathOfUpdatedObject: IndexPath!) {
        collectionView.reloadData()
    }
    
    // 5/20/16; Odd. This gets called when an object is updated, sometimes. It may be because the sorting key I'm using in the fetched results controller changed.
    func coreDataSource(_ cds: CoreDataSource!, objectWasMovedFrom oldIndexPath: IndexPath!, to newIndexPath: IndexPath!) {
        collectionView.reloadData()
    }
}

extension ImagesVC : SyncControllerDelegate {
    func addLocalImage(syncController:SyncController, url:SMRelativeLocalURL, uuid:String, mimeType:String, title:String?, creationDate: NSDate?) {
        // We're making an image for which there is already a UUID on the server.
        addLocalImage(newImageURL: url, mimeType: mimeType, uuid:uuid, title:title, creationDate: creationDate)
    }
    
    func removeLocalImage(syncController:SyncController, uuid:String) {
        removeLocalImage(uuid: uuid)
    }
    
    func syncEvent(syncController:SyncController, event:SyncControllerEvent) {
        switch event {
        case .syncStarted:
            if !self.spinner.animating {
                timeThatSpinnerStarts = CFAbsoluteTimeGetCurrent()
                self.spinner.start()
            }
            
        case .syncDone:
            // If we don't let the spinner show for a minimum amount of time, it looks odd.
            let minimumDuration:CFTimeInterval = 2
            let difference:CFTimeInterval = CFAbsoluteTimeGetCurrent() - timeThatSpinnerStarts
            if difference > minimumDuration {
                self.spinner.stop()
            }
            else {
                let waitingTime = minimumDuration - difference
                
                TimedCallback.withDuration(Float(waitingTime)) {
                    self.spinner.stop()
                }
            }
            
        case .syncError:
            self.spinner.stop(withBackgroundColor: .red)
        }
        
        self.spinner.setNeedsLayout()
    }
    
    func completedAddingLocalImages() {
        scrollIfNeeded(animated: true)
    }
}

extension ImagesVC : UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
    
        let proportion:CGFloat = 0.30
        // Estimate a suitable size for the cell. proportion*100% of the width of the collection view.
        let size = collectionView.frame.width * proportion
        let boundingCellSize = CGSize(width: size, height: size)
        
        // And then figure out how big the image will be.
        let image = self.coreDataSource.object(at: indexPath) as! Image
        let boundedImageSize = ImageExtras.boundingImageSizeFor(originalSize: image.originalSize, boundingSize: boundingCellSize)

        return CGSize(width: boundedImageSize.width, height: boundedImageSize.height)
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumLineSpacingForSectionAt section: Int) -> CGFloat {
        return 10.0
    }
}
