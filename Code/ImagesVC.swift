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
import SyncServer_Shared

class ImagesVC: UIViewController {
    // TODO: Need to provide this!!
    var sharingGroupUUID: String!
    
    let reuseIdentifier = "ImageIcon"
    var acquireImage:SMAcquireImage!
    var addImageBarButton:UIBarButtonItem!
    var actionButton:UIBarButtonItem!
    var coreDataSource:CoreDataSource!
    var syncController = SyncController()
    
    // To enable pulling down on the table view to initiate a sync with server. This spinner is displayed only momentarily, but you can always do the pull down to sync/refresh.
    var refreshControl:ODRefreshControl!
    
    @IBOutlet weak var collectionView: UICollectionView!
    
    fileprivate var navigatedToLargeImages = false
    
    fileprivate var imageCache:LRUCache<Image>! {
        return ImageExtras.imageCache
    }

    private var bottomRefresh:BottomRefresh!
    
    // Selection (via long-press) to allow user to select images for sending via text messages, email (etc), or for deletion.
    typealias UUIDString = String
    fileprivate var selectedImages = Set<UUIDString>()
    
    private var deletedImages:[IndexPath]?
    private var noDownloadImageView:UIImageView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        collectionView.dataSource = self
        collectionView.delegate = self

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
        titleLabel.text = "Images"
        titleLabel.sizeToFit()
        navigationItem.titleView = titleLabel
        let lp = UILongPressGestureRecognizer(target: self, action: #selector(consistencyCheckAction(gesture:)))
        titleLabel.addGestureRecognizer(lp)
        titleLabel.isUserInteractionEnabled = true
        
        // Right nav button
        addImageBarButton = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(addImageAction))
        setAddButtonState()
        setupRightBarButtonItems()
        
        // For sharing images via email, text messages, and for deleting images.
        actionButton = UIBarButtonItem(image: #imageLiteral(resourceName: "Action"), style: .plain, target: self, action: #selector(actionButtonAction))
        
        let noDownloadImage = #imageLiteral(resourceName: "noDownloads").withRenderingMode(.alwaysTemplate)
        noDownloadImageView = UIImageView(image: noDownloadImage)
        let noDownloadsButton = UIBarButtonItem(customView: noDownloadImageView)
        navigationItem.leftBarButtonItems = [actionButton, noDownloadsButton]
        noDownloadImageView.alpha = 0
        noDownloadImageView.tintColor = .lightGray
        
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        bottomRefresh = BottomRefresh(withScrollView: collectionView, scrollViewParent: appDelegate.tabBarController.view, refreshAction: {
            do {
                try self.syncController.sync(sharingGroupUUID: self.sharingGroupUUID)
            } catch (let error) {
                SMCoreLib.Alert.show(fromVC: self, withTitle: "Could not sync", message: "\(error)")
            }
        })
    }
    
    private func setupRightBarButtonItems() {
        var sortImage:UIImage
        if Parameters.sortingOrderIsAscending {
            sortImage = #imageLiteral(resourceName: "sortFilterUp")
        }
        else {
            sortImage = #imageLiteral(resourceName: "sortFilterDown")
        }
        
        sortImage = sortImage.withRenderingMode(.alwaysTemplate)
        
        let sortFilter = UIBarButtonItem(image: sortImage, style: .plain, target: self, action: #selector(sortFilterAction))
        
        if Parameters.filterApplied {
            sortFilter.tintColor = .lightGray
        }
        
        navigationItem.rightBarButtonItems = [addImageBarButton!, sortFilter]
    }
    
    @objc private func sortFilterAction() {
        SortyFilter.show(fromParentVC: self, delegate: self)
    }
    
    func remove(images:[Image]) {
        // The sync/remote remove must happen before the local remove-- or we lose the reference!
        
        // 11/26/17; I got an error here "fileAlreadyDeleted". https://github.com/crspybits/SharedImages/issues/56-- `syncController.remove` failed.
        if !syncController.remove(images: images, sharingGroupUUID: sharingGroupUUID) {
            var message = "Image"
            if images.count > 1 {
                message += "s"
            }
            
            message += " already deleted on server."
            
            SMCoreLib.Alert.show(withTitle: "Error", message: message)
            Log.error("Error: \(message)")
            
            // I'm not going to return here. Even if somehow the image was already deleted on the server, let's make sure it was deleted locally.
        }
        
        // 12/2/17, 12/25/17; This is tricky. See https://github.com/crspybits/SharedImages/issues/61 and https://stackoverflow.com/questions/47614583/delete-multiple-core-data-objects-issue-with-nsfetchedresultscontroller
        // I'm dealing with this below. See the reference to this SO issue below.
        for image in images {
            // This also removes any associated discussion.
            do {
                try image.remove()
            }
            catch (let error) {
                Log.error("Could not remove image: \(error)")
            }
        }
        
        CoreData.sessionNamed(CoreDataExtras.sessionName).saveContext()
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
        
        var position:UICollectionView.ScrollPosition
        var indexPath:IndexPath
        
        if Parameters.sortingOrderIsAscending {
            indexPath = IndexPath(item: count-1, section: 0)
            position = .top
            
            // Getting an odd effect-- of LottiesBottom showing if we have newer at bottom.
            bottomRefresh.animating = false
        }
        else {
            indexPath = IndexPath(item: 0, section: 0)
            position = .bottom
        }

        UIView.animate(withDuration: 0.3, animations: {
            self.collectionView.scrollToItem(at: indexPath, at: position, animated: false)
        }) { success in
            self.bottomRefresh.animating = true
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
            
            self.bottomRefresh?.didRotate()
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        coreDataSource.fetchData()

        // 6/16/18; Used to have this in `viewDidAppear`, but I'm getting a crash in that case when the filter is on to only see images with unread messages-- and coming back from large images. See https://github.com/crspybits/SharedImages/issues/123
        // To clear unread count(s)-- both in the case of coming back from navigating to large images, and in the case of resetting unread counts in Settings.
        collectionView.reloadData()
        
        Progress.session.viewController = self
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
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // https://github.com/crspybits/SharedImages/issues/121 (a)
        bottomRefresh.hide()
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
        do {
            try SyncServer.session.consistencyCheck(sharingGroupUUID: sharingGroupUUID, localFiles: uuids, repair: false) { error in }
        } catch (let error) {
            SMCoreLib.Alert.show(fromVC: self, withTitle: "Problem in consistency check", message: "\(error)")
        }
    }
    
    @objc private func refresh() {
        self.refreshControl.endRefreshing()
        
        do {
            try syncController.sync(sharingGroupUUID: sharingGroupUUID)
        } catch (let error) {
            SMCoreLib.Alert.show(fromVC: self, withTitle: "Could not sync", message: "\(error)")
        }
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
    func addLocalImage(newImageData: ImageData, fileGroupUUID: String?) -> Image {
        var newImage:Image!
        
        if newImageData.file.fileUUID == nil {
            // We're creating a new image at the user's request.
            newImage = Image.newObjectAndMakeUUID(makeUUID: true, creationDate: newImageData.creationDate) as? Image
        }
        else {
            newImage = Image.newObjectAndMakeUUID(makeUUID: false, creationDate: newImageData.creationDate) as? Image
            newImage.uuid = newImageData.file.fileUUID
        }

        newImage.url = newImageData.file.url
        newImage.mimeType = newImageData.file.mimeType.rawValue
        newImage.title = newImageData.title
        newImage.discussionUUID = newImageData.discussionUUID
        newImage.fileGroupUUID = fileGroupUUID
        newImage.sharingGroupUUID = newImageData.file.sharingGroupUUID
        
        let imageFileName = newImageData.file.url.lastPathComponent
        let size = ImageStorage.size(ofImage: imageFileName, withPath: ImageExtras.largeImageDirectoryURL)
        newImage.originalHeight = Float(size.height)
        newImage.originalWidth = Float(size.width)
        
        // Lookup the Discussion and connect it if we have it.
        
        var discussion:Discussion?
        
        if let discussionUUID = newImageData.discussionUUID {
            discussion = Discussion.fetchObjectWithUUID(discussionUUID)
        }
        
        if discussion == nil, let fileGroupUUID = newImageData.fileGroupUUID {
            discussion = Discussion.fetchObjectWithFileGroupUUID(fileGroupUUID)
        }
        
        newImage.discussion = discussion
        
        if discussion != nil {
            // 4/17/18; If that discussion has the image title, get that too.
            if newImageData.title == nil {
                if let url = discussion!.url,
                    let fixedObjects = FixedObjects(withFile: url as URL) {
                    newImage.title = fixedObjects[DiscussionKeys.imageTitleKey] as? String
                }
                else {
                    Log.error("Could not load discussion!")
                }
            }
        }

        CoreData.sessionNamed(CoreDataExtras.sessionName).saveContext()
        
        return newImage
    }
    
    enum AddToDiscussion {
        case newLocalDiscussion
        case fromServer
    }
    
    // Three cases: 1) new discussion added locally (uuid of the FileData will be nil), 2) update to existing local discussion (with data from server), and 3) new discussion from server.
    @discardableResult
    func addToLocalDiscussion(discussionData: FileData, type: AddToDiscussion, fileGroupUUID: String?) -> Discussion {
        var localDiscussion: Discussion!
        var imageTitle: String?
        
        switch type {
        case .newLocalDiscussion:
            // 1)
            localDiscussion = (Discussion.newObjectAndMakeUUID(makeUUID: false) as! Discussion)
            localDiscussion.uuid = discussionData.fileUUID
            localDiscussion.sharingGroupUUID = discussionData.sharingGroupUUID

        case .fromServer:
            if let existingLocalDiscussion = Discussion.fetchObjectWithUUID(discussionData.fileUUID!) {
                // 2) Update to existing local discussion-- this is a main use case. I.e., no conflict and we got new discussion message(s) from the server (i.e., from other users(s)).
                
                localDiscussion = existingLocalDiscussion
                
                // Since we didn't have a conflict, `newFixedObjects` will be a superset of the existing objects.
                if let newFixedObjects = FixedObjects(withFile: discussionData.url as URL),
                    let existingDiscussionURL = existingLocalDiscussion.url,
                    let oldFixedObjects = FixedObjects(withFile: existingDiscussionURL as URL) {
                    
                    // We still want to know how many new messages there are.
                    let (_, newCount) = oldFixedObjects.merge(with: newFixedObjects)
                    // Use `+=1` here because there may already be unread messages.
                    existingLocalDiscussion.unreadCount += Int32(newCount)
                    
                    // Remove the existing discussion file
                    do {
                        try FileManager.default.removeItem(at: existingDiscussionURL as URL)
                    } catch (let error) {
                        Log.error("Error removing old discussion file: \(error)")
                    }
                    
                    imageTitle = newFixedObjects[DiscussionKeys.imageTitleKey] as? String
                }
            }
            else {
                // 3) New discussion downloaded from server.
                localDiscussion = (Discussion.newObjectAndMakeUUID(makeUUID: false) as! Discussion)
                localDiscussion.uuid = discussionData.fileUUID
                localDiscussion.sharingGroupUUID = discussionData.sharingGroupUUID
                
                // This is a new discussion, downloaded from the server. We can update the unread count on the discussion with the total discussion content size.
                if let fixedObjects = FixedObjects(withFile: discussionData.url as URL) {
                    localDiscussion.unreadCount = Int32(fixedObjects.count)
                    imageTitle = fixedObjects[DiscussionKeys.imageTitleKey] as? String
                }
                else {
                    Log.error("Could not load discussion!")
                }
            }
        }
        
        localDiscussion.mimeType = discussionData.mimeType.rawValue
        localDiscussion.url = discussionData.url
        localDiscussion.fileGroupUUID = fileGroupUUID

        // Look up and connect the Image if we have one.
        var image:Image?
        
        // The two means of getting the image reflect different strategies for doing this over time in SharedImages/SyncServer development.
        
        // See if the image has an asssociated discussionUUID
        image = Image.fetchObjectWithDiscussionUUID(localDiscussion.uuid!)

        // If not, see if a fileGroupUUID connects the discussion and image.
        if image == nil, let fileGroupUUID = localDiscussion.fileGroupUUID {
            image = Image.fetchObjectWithFileGroupUUID(fileGroupUUID)
        }
        
        if image != nil {
            localDiscussion.image = image
            
            // 4/17/18; If this discussion has the image title, set the image title from that.
            if let imageTitle = imageTitle {
                image!.title = imageTitle
            }
        }
        
        CoreData.sessionNamed(CoreDataExtras.sessionName).saveContext()
        UnreadCountBadge.update()
        
        return localDiscussion
    }
    
    func removeLocalImages(uuids:[String]) {
        ImageExtras.removeLocalImages(uuids:uuids)
    }
    
    private func createEmptyDiscussion(image:Image, discussionUUID: String, sharingGroupUUID: String, imageTitle: String?) -> FileData? {
        let newDiscussionFileURL = ImageExtras.newJSONFile()
        var fixedObjects = FixedObjects()
        
        // This is so that we have the possibility of reconstructing the image/discussions if we lose the server data. This will explicitly connect the discussion to the image.
        fixedObjects[DiscussionKeys.imageUUIDKey] = image.uuid
        
        // 4/17/18; Image titles are now stored in the "discussion" file. This may reduce the amount of data we need store in the server database.
        fixedObjects[DiscussionKeys.imageTitleKey] = imageTitle

        do {
            try fixedObjects.save(toFile: newDiscussionFileURL as URL)
        }
        catch (let error) {
            Log.error("Error saving new discussion thread to file: \(error)")
            SMCoreLib.Alert.show(fromVC: self, withTitle: "Alert!", message: "Problem creating discussion thread.")
            return nil
        }
        
        return FileData(url: newDiscussionFileURL, mimeType: .text, fileUUID: discussionUUID, sharingGroupUUID: sharingGroupUUID)
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
    
        // There was a crash here when I force unwrapped both of these. Not sure how. I've changed to to optional chaining. See https://github.com/crspybits/SharedImages/issues/57 We'll get an empty/nil title in that case.
        let userName = SignInManager.session.currentSignIn?.credentials?.username
        if userName == nil {
            Log.error("userName was nil: SignInManager.session.currentSignIn: \(String(describing: SignInManager.session.currentSignIn)); SignInManager.session.currentSignIn?.credentials: \(String(describing: SignInManager.session.currentSignIn?.credentials))")
        }
        
        guard let mimeTypeEnum = MimeType(rawValue: mimeType) else {
            SMCoreLib.Alert.show(fromVC: self, withTitle: "Alert!", message: "Unknown mime type: \(mimeType)")
            return
        }
        
        guard let newDiscussionUUID = UUID.make(), let fileGroupUUID = UUID.make() else {
            SMCoreLib.Alert.show(fromVC: self, withTitle: "Alert!", message: "Could not create  UUID(s)")
            return
        }
        
        let imageFileData = FileData(url: newImageURL, mimeType: mimeTypeEnum, fileUUID: nil, sharingGroupUUID: sharingGroupUUID)
        let imageData = ImageData(file: imageFileData, title: userName, creationDate: nil, discussionUUID: newDiscussionUUID, fileGroupUUID: fileGroupUUID)
        
        // We're making an image that the user of the app added-- we'll generate a new UUID.
        let newImage = addLocalImage(newImageData: imageData, fileGroupUUID:fileGroupUUID)
        newImage.sharingGroupUUID = sharingGroupUUID
        
        guard let newDiscussionFileData = createEmptyDiscussion(image: newImage, discussionUUID: newDiscussionUUID, sharingGroupUUID: sharingGroupUUID, imageTitle: userName) else {
            return
        }
        
        let newDiscussion = addToLocalDiscussion(discussionData: newDiscussionFileData, type: .newLocalDiscussion, fileGroupUUID: fileGroupUUID)
        newDiscussion.sharingGroupUUID = sharingGroupUUID
        
        scrollIfNeeded(animated:true)
        
        // Sync this new image & discussion with the server.
        syncController.add(image: newImage, discussion: newDiscussion)
    }
}

extension ImagesVC : CoreDataSourceDelegate {
    // This must have sort descriptor(s) because that is required by the NSFetchedResultsController, which is used internally by this class.
    func coreDataSourceFetchRequest(_ cds: CoreDataSource!) -> NSFetchRequest<NSFetchRequestResult>! {
        let params = Image.SortFilterParams(sortingOrder: Parameters.sortingOrder, isAscending: Parameters.sortingOrderIsAscending, unreadCounts: Parameters.unreadCounts)
        return Image.fetchRequestForAllObjects(params: params)
    }
    
    func coreDataSourceContext(_ cds: CoreDataSource!) -> NSManagedObjectContext! {
        return CoreData.sessionNamed(CoreDataExtras.sessionName).context
    }

    // 12/25/17; See https://github.com/crspybits/SharedImages/issues/61 and https://stackoverflow.com/questions/47614583/delete-multiple-core-data-objects-issue-with-nsfetchedresultscontroller Going to deal with this issue by accumulating index paths of images we're deleting, and then doing all of the deletions at once.
    func coreDataSourceWillChangeContent(_ cds: CoreDataSource!) {
        deletedImages = []
    }
    
    func coreDataSourceDidChangeContent(_ cds: CoreDataSource!) {
        if let deletedImages = deletedImages, deletedImages.count > 0 {
            collectionView.deleteItems(at: deletedImages)
        }
        
        deletedImages = nil
    }
    
    // Should return YES iff the context save was successful.
    func coreDataSourceSaveContext(_ cds: CoreDataSource!) -> Bool {
        return CoreData.sessionNamed(CoreDataExtras.sessionName).saveContext()
    }
    
    func coreDataSource(_ cds: CoreDataSource!, objectWasDeleted indexPathOfDeletedObject: IndexPath!) {
        Log.msg("objectWasDeleted: indexPathOfDeletedObject: \(String(describing: indexPathOfDeletedObject))")
        deletedImages?.append(indexPathOfDeletedObject)
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
    func addLocalImage(syncController:SyncController, imageData: ImageData, attr: SyncAttributes) {
        // We're making an image for which there is already a UUID on the server.
        addLocalImage(newImageData: imageData, fileGroupUUID: attr.fileGroupUUID)
    }
    
    func addToLocalDiscussion(syncController:SyncController, discussionData: FileData, attr: SyncAttributes) {
        addToLocalDiscussion(discussionData: discussionData, type: .fromServer, fileGroupUUID: attr.fileGroupUUID)
    }
    
    func updateUploadedImageDate(syncController:SyncController, uuid: String, creationDate: NSDate) {
        // We provided the content for the image, but the server establishes its date of creation. So, update our local image date/time with the creation date from the server.
        if let image = Image.fetchObjectWithUUID(uuid) {
            image.creationDate = creationDate as NSDate
            image.save()
        }
        else {
            Log.error("Could not find image for UUID: \(uuid)")
        }
    }

    func removeLocalImages(syncController: SyncController, uuids: [String]) {
        removeLocalImages(uuids: uuids)
    }
    
    func syncEvent(syncController:SyncController, event:SyncControllerEvent) {
        switch event {
        case .syncDelayed:
            // Trying to deal with https://github.com/crspybits/SharedImages/issues/126
            self.bottomRefresh.hide()
            
        case .syncStarted:
            // Put this hide here (instead of in syncDone) to try to deal with https://github.com/crspybits/SharedImages/issues/121 (c)
            self.bottomRefresh.hide()
            
        case .syncDone (let numberOperations):
            // 8/12/17; https://github.com/crspybits/SharedImages/issues/13
            AppBadge.setBadge(number: 0)
            
            Progress.session.finish()
                        
            // 2/13/18; I had been resetting the unread counts on first use of the app, but I don't think that's appropriate. See https://github.com/crspybits/SharedImages/issues/83
            
            // To refresh the badge unread counts, if we have new messages.
            collectionView.reloadData()
            
            // Because no downloads or uploads occurred, give the user a positive indication that we indeed did something.
            if numberOperations == 0 {
                UIView.animate(withDuration: 0.2) {
                    self.noDownloadImageView.alpha = 1
                }
                
                TimedCallback.withDuration(2) {
                    UIView.animate(withDuration: 0.2) {
                        self.noDownloadImageView.alpha = 0
                    }
                }
            }
            
        case .syncError(let message):
            self.bottomRefresh.hide()
            SMCoreLib.Alert.show(fromVC: self, withTitle: "Alert!", message: message)
        }
    }
    
    func completedAddingLocalImages(syncController:SyncController) {
        scrollIfNeeded(animated: true)
    }
    
    func redoImageUpload(syncController: SyncController, forDiscussion attr: SyncAttributes) {
        guard let discussion = Discussion.fetchObjectWithUUID(attr.fileUUID) else {
            Log.error("Cannot find discussion for attempted image re-upload.")
            return
        }
        
        guard let image = discussion.image, let imageURL = image.url, let imageUUID = image.uuid else {
            Log.error("Cannot find image for attempted image re-upload.")
            return
        }
        
        let attr = SyncAttributes(fileUUID: imageUUID, sharingGroupUUID: sharingGroupUUID, mimeType: .jpeg)
        do {
            try SyncServer.session.uploadImmutable(localFile: imageURL, withAttributes: attr)
            try SyncServer.session.sync(sharingGroupUUID: sharingGroupUUID)
        }
        catch (let error) {
            Log.error("Could not do uploadImmutable for image re-upload: \(error)")
            return
        }
    }
}

extension ImagesVC : UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
    
        let proportion:CGFloat = 0.30
        // Estimate a suitable size for the cell. proportion*100% of the width of the collection view.
        let size = collectionView.frame.width * proportion
        let boundingCellSize = CGSize(width: size, height: size)
        
        // And then figure out how big the image will be.
        // Seems like the crash Dany was getting was here: https://github.com/crspybits/SharedImages/issues/123
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
            if let imageObj = Image.fetchObjectWithUUID(uuidString) {
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

extension ImagesVC : SortyFilterDelegate {
    func sortyFilter(sortFilterByParameters: SortyFilter) {
        coreDataSource.fetchData()
        setupRightBarButtonItems()
        collectionView.reloadData()
    }
}
