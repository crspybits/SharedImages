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
import ODRefreshControl
import LottiesBottom

class ImagesVC: UIViewController {
    let reuseIdentifier = "ImageIcon"
    var acquireImage:SMAcquireImage!
    var addImageBarButton:UIBarButtonItem!
    var actionButton:UIBarButtonItem!
    var coreDataSource:CoreDataSource!
    var syncController = SyncController()
    
    // To enable pulling down on the table view to initiate a sync with server. This spinner is displayed only momentarily, but you can always do the pull down to sync/refresh.
    var refreshControl:ODRefreshControl!
    
    @IBOutlet weak var collectionView: UICollectionView!
    
    // Spinner for controlling/indicating sync with SyncServer. This spinner is displayed for as long as the synchronization operation with the SyncServer takes. It's not visible or available afterwards, unless an error occurs.
    var spinner:SyncSpinner!
    var timeThatSpinnerStarts:CFTimeInterval!
    
    fileprivate var navigatedToLargeImages = false
    
    fileprivate var imageCache:LRUCache<Image>! {
        return ImageExtras.imageCache
    }
    
    private var bottomAnimation:LottiesBottom!
    
    // Selection (via long-press) to allow user to select images for sending via text messages, email (etc), or for deletion.
    typealias UUIDString = String
    fileprivate var selectedImages = Set<UUIDString>()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        collectionView.dataSource = self
        collectionView.delegate = self
        
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
        
        // Long press on image to select.
        collectionView.alwaysBounceVertical = true
        let imageSelectionLongPress = UILongPressGestureRecognizer(target: self, action: #selector(imageSelectionLongPressAction(gesture:)))
        imageSelectionLongPress.delaysTouchesBegan = true
        collectionView?.addGestureRecognizer(imageSelectionLongPress)
        
        // A label and a means to do a consistency check.
        let titleLabel = UILabel()
        titleLabel.text = "Shared Images"
        titleLabel.sizeToFit()
        navigationItem.titleView = titleLabel
        let lp = UILongPressGestureRecognizer(target: self, action: #selector(consistencyCheckAction(gesture:)))
        titleLabel.addGestureRecognizer(lp)
        titleLabel.isUserInteractionEnabled = true
        
        // Spinner that shows when syncing
        let spinnerSize:CGFloat = 25
        spinner = SyncSpinner(frame: CGRect(x: 0, y: 0, width: spinnerSize, height: spinnerSize))
        let spinnerButton = UIButton()
        spinnerButton.backgroundColor = UIColor.clear
        spinnerButton.frame = CGRect(x: 0, y: 0, width: spinnerSize, height: spinnerSize)
        spinnerButton.addSubview(spinner)
        let spinnerBarButtonItem = UIBarButtonItem(customView: spinnerButton)
        
        // For sharing images via email, text messages, and for deleting images.
        let actionImage = UIImage(named: "Action")
        actionButton = UIBarButtonItem(image: actionImage, style: .plain, target: self, action: #selector(actionButtonAction))
        
        navigationItem.setLeftBarButtonItems([actionButton, spinnerBarButtonItem], animated: false)
        
        let size = CGSize(width: 200, height: 85)
        let animationLetters = ["C", "R", "D", "N"]
        let whichAnimation = Int(arc4random_uniform(UInt32(animationLetters.count)))
        let animationLetter = animationLetters[whichAnimation]
        
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        let tabBarHeight = appDelegate.tabBarController.tabBar.frame.size.height
        
        bottomAnimation = LottiesBottom(useLottieJSONFileWithName: animationLetter, withSize: size, scrollView: self.collectionView, scrollViewParent: appDelegate.tabBarController.view, bottomYOffset: -tabBarHeight) {[unowned self] in
            self.syncController.sync()
            self.bottomAnimation.hide()
        }
        bottomAnimation.completionThreshold = 0.5
        
        // Getting an odd effect-- of LottiesBottom showing initially or if we have newer at bottom.
        bottomAnimation.animating = false
    }
    
    func remove(images:[Image]) {
        // The sync/remote remove must happen before the local remove-- or we lose the reference!
        
        if !syncController.remove(images: images) {
            var message = "Could not delete image"
            if images.count > 1 {
                message += "s"
            }
            
            SMCoreLib.Alert.show(withTitle: "Error", message: message)
            return
        }
        
        for image in images {
            CoreData.sessionNamed(CoreDataExtras.sessionName).remove(image)
        }
        
        CoreData.sessionNamed(CoreDataExtras.sessionName).saveContext()
        // 8/24/17; Looks like I got a crash here. This may have been because I was not deleting a set of images atomically.
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        ImageExtras.resetToSmallerImageCache() {
            collectionView?.reloadData()
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
            
            // Getting an odd effect-- of LottiesBottom showing if we have newer at bottom.
            bottomAnimation.animating = false
        }

        UIView.animate(withDuration: 0.3, animations: {
            self.collectionView.scrollToItem(at: indexPath, at: position, animated: false)
        }) { success in
            self.bottomAnimation.animating = true
        }
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
        coordinator.animate(alongsideTransition: { context in
        }) {[unowned self] context in
            // I made this an optional because, oddly, I can get in here when I've never navigated to this tab.
            self.collectionView?.reloadData()
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        coreDataSource.fetchData()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        // If we navigated to the large images and are just coming back now, don't bother with the scrolling.
        if navigatedToLargeImages {
            navigatedToLargeImages = false
        }
        else {
            scrollIfNeeded(animated: true)
        }

        AppBadge.checkForBadgeAuthorization(usingViewController: self)
        setAddButtonState()
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
    
    @objc private func refresh() {
        self.refreshControl.endRefreshing()
        syncController.sync()
    }
    
    // Enable a reset from error when needed.
    @objc private func spinnerTapGestureAction() {
        Log.msg("spinner tapped")
        refresh()
    }
    
    @objc func addImageAction() {
        self.acquireImage.showAlert(fromBarButton: addImageBarButton)
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
    
    func removeLocalImages(uuids:[String]) {
        ImageExtras.removeLocalImages(uuids:uuids)
    }
}

extension ImagesVC : UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let largeImages = storyboard!.instantiateViewController(withIdentifier: "LargeImages") as! LargeImages
        largeImages.startItem = indexPath.item
        largeImages.syncController = syncController
        navigatedToLargeImages = true
        navigationController!.pushViewController(largeImages, animated: true)
    }
    
    func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        (cell as! ImageCollectionVC).cellSizeHasBeenChanged()
        Log.msg("cell.frame: \(cell.frame)")
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
        let imageObj = self.coreDataSource.object(at: indexPath) as! Image
        cell.setProperties(image: imageObj, syncController: syncController, cache: imageCache)
        
        showSelectedState(imageUUID: imageObj.uuid!, cell: cell)

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
    
    func removeLocalImages(syncController: SyncController, uuids: [String]) {
        removeLocalImages(uuids: uuids)
    }
    
    func syncEvent(syncController:SyncController, event:SyncControllerEvent) {
        switch event {
        case .syncStarted:
            if !self.spinner.animating {
                timeThatSpinnerStarts = CFAbsoluteTimeGetCurrent()
                self.spinner.start()
            }
            
        case .syncDone:
            // 8/12/17; https://github.com/crspybits/SharedImages/issues/13
            AppBadge.setBadge(number: 0)
            
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

        return CGSize(width: boundedImageSize.width, height: boundedImageSize.height + ImageCollectionVC.smallTitleHeight)
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumLineSpacingForSectionAt section: Int) -> CGFloat {
        return 10.0
    }
}

// MARK: Sharing and deletion activity.
extension ImagesVC {
    @objc fileprivate func actionButtonAction() {
        // Create an array containing both UIImage's and Image's. The UIActivityViewController will use the UIImage's. The TrashActivity will use the Image's.
        var images = [Any]()
        for uuidString in selectedImages {
            if let imageObj = Image.fetchObjectWithUUID(uuid: uuidString) {
                let uiImage = ImageExtras.fullSizedImage(url: imageObj.url! as URL)
                images.append(uiImage)
                images.append(imageObj)
            }
        }
        
        if images.count == 0 {
            Log.warning("No images selected!")
            SMCoreLib.Alert.show(withTitle:  "No images selected!", message: "Long-press on image(s) to select, and then try again.")
            return
        }
        
        // 8/19/17; It looks like you can't control the order of the actions in the list supplied by this control. See https://stackoverflow.com/questions/19060535/how-to-rearrange-activities-on-a-uiactivityviewcontroller
        // Unfortunately, this means the deletion control occurs off to the right-- and I can't see it w/o scrolling on my iPhone6
        let trashActivity = TrashActivity(withParentVC: self, removeImages: { images in
            self.remove(images: images)
        })
        let activityViewController = UIActivityViewController(activityItems: images, applicationActivities: [trashActivity])
        
        activityViewController.completionWithItemsHandler = { activityType, completed, returnedItems, error in
            if completed {
                // Action has been carried out (e.g., image has been deleted), remove selected icons.
                self.selectedImages.removeAll()
                
                self.collectionView.reloadData()
            }
        }
        
        // 8/26/17; https://github.com/crspybits/SharedImages/issues/29
        activityViewController.popoverPresentationController?.sourceView = view
        
        present(activityViewController, animated: true, completion: {})
    }
    
    @objc fileprivate func imageSelectionLongPressAction(gesture : UILongPressGestureRecognizer!) {
        if gesture.state == .began {
            let p = gesture.location(in: self.collectionView)
            if let indexPath = collectionView.indexPathForItem(at: p) {
                let imageObj = coreDataSource.object(at: indexPath) as! Image
                
                if selectedImages.contains(imageObj.uuid!) {
                    // Deselect image
                    selectedImages.remove(imageObj.uuid!)
                }
                else {
                    // Select image
                    selectedImages.insert(imageObj.uuid!)
                }

                let cell = self.collectionView.cellForItem(at: indexPath) as! ImageCollectionVC
                showSelectedState(imageUUID: imageObj.uuid!, cell: cell)
            }
        }
    }
    
    fileprivate func showSelectedState(imageUUID:String, cell:UICollectionViewCell) {        
        if let cell = cell as? ImageCollectionVC {
            cell.userSelected = selectedImages.contains(imageUUID)
        }
    }
}
