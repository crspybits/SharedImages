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
import DropDown

class ImagesVC: UIViewController {
    // Set these before showing screen.
    var sharingGroup: SyncServer.SharingGroup!
    var imagesHandler: ImagesHandler!
    var initialSync = false
    
    let reuseIdentifier = "ImageIcon"
    var acquireImages: AcquireImages!
    var otherActionBarButton:UIBarButtonItem!
    var coreDataSource:CoreDataSource!
    
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
    private let otherActions = DropDown()
    private var dropDownMenuItems:[DropDownMenuItem]!
    
    static func create() -> ImagesVC {
        return UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "ImagesVC") as! ImagesVC
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        collectionView.dataSource = self
        collectionView.delegate = self

        acquireImages = AcquireImages(withParentViewController: self)
        acquireImages.delegate = self
        
        coreDataSource = CoreDataSource(delegate: self)
        
        // To manually refresh-- pull down on collection view.
        refreshControl = ODRefreshControl.create(scrollView: collectionView, nav: navigationController!, target: self, selector: #selector(refresh))
        
        // Long press on image to select.
        collectionView.alwaysBounceVertical = true
        let imageSelectionLongPress = UILongPressGestureRecognizer(target: self, action: #selector(imageSelectionLongPressAction(gesture:)))
        imageSelectionLongPress.delaysTouchesBegan = true
        collectionView?.addGestureRecognizer(imageSelectionLongPress)
        
        // A label and a means to do a consistency check.
        let titleLabel = UILabel()
        titleLabel.text = sharingGroup.sharingGroupName ?? "Album Images"
        titleLabel.sizeToFit()
        navigationItem.titleView = titleLabel
        let lp = UILongPressGestureRecognizer(target: self, action: #selector(consistencyCheckAction(gesture:)))
        titleLabel.addGestureRecognizer(lp)
        titleLabel.isUserInteractionEnabled = true
        
        // Right nav button
        let otherActionButton = UIButton(type: .system)
        otherActionButton.setImage(#imageLiteral(resourceName: "otherDetails"), for: .normal)
        otherActionButton.addTarget(self, action: #selector(otherActionButtonAction), for: .touchUpInside)
        otherActionBarButton = UIBarButtonItem(customView: otherActionButton)
        setupDropdown(anchorView: otherActionButton)
        
        setupRightBarButtonItems()
        
        let backButton = UIBarButtonItem(image: #imageLiteral(resourceName: "back"), style: .plain, target: self, action: #selector(backAction))
        
        let noDownloadImage = #imageLiteral(resourceName: "noDownloads").withRenderingMode(.alwaysTemplate)
        noDownloadImageView = UIImageView(image: noDownloadImage)
        
        let noDownloadsButton = UIBarButtonItem(customView: noDownloadImageView)
        navigationItem.leftBarButtonItems = [backButton, noDownloadsButton]
        noDownloadImageView.alpha = 0
        noDownloadImageView.tintColor = .lightGray
        
        // Because, when app enters background, AppBadge sets itself up to use handlers.
        NotificationCenter.default.addObserver(self, selector:#selector(setupHandlers), name:
            UIApplication.willEnterForegroundNotification, object: nil)
        
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        bottomRefresh = BottomRefresh(withScrollView: collectionView, scrollViewParent: appDelegate.tabBarController.view, refreshAction: { [unowned self] in
            Log.msg("bottomRefresh: starting sync")
            do {
                try self.imagesHandler.syncController.sync(sharingGroupUUID: self.sharingGroup.sharingGroupUUID)
            } catch (let error) {
                SMCoreLib.Alert.show(fromVC: self, withTitle: "Could not sync", message: "\(error)")
            }
        })
    }
    
    @objc private func setupHandlers() {
        imagesHandler.syncEventAction = syncEvent
        imagesHandler.completedAddingOrUpdatingLocalImagesAction = completedAddingOrUpdatingLocalImages
    }
    
    @objc private func otherActionButtonAction() {
        otherActions.clearSelection()
        otherActions.show()
    }
    
    private struct DropDownMenuItem {
        let name: String
        let action: (()->())
    }
    
    private func setupDropdown(anchorView: UIButton) {
        otherActions.anchorView = anchorView
        otherActions.dismissMode = .automatic
        otherActions.direction = .any
        
        dropDownMenuItems = []
        
        if sharingGroup.permission.hasMinimumPermission(.write) {
            dropDownMenuItems += [DropDownMenuItem(name: "Add Image(s)", action: {
                self.acquireImages.showAlert(fromBarButton: self.otherActionBarButton)
            })]
        }
        
        if sharingGroup.permission.hasMinimumPermission(.admin) {
            dropDownMenuItems += [DropDownMenuItem(name: "Share Album", action: {
                [unowned self] in
                self.shareAction()
            })]
        }
        
        dropDownMenuItems += [
            DropDownMenuItem(name: "Other Actions", action: {[unowned self] in
                self.actionButtonAction()
            }),
            DropDownMenuItem(name: "Remove Album", action: {[unowned self] in
                self.removeUserFromAlbum()
            })
        ]
        
        otherActions.selectionAction = { [unowned self] (index, item) in
            if index < self.dropDownMenuItems.count {
                let action = self.dropDownMenuItems[index].action
                action()
            }
            
            self.otherActions.hide()
        }

        let menuNames = dropDownMenuItems.map {$0.name}
        otherActions.dataSource = menuNames
    }
    
    private func removeUserFromAlbum() {
        SMCoreLib.Alert.show(fromVC: self, withTitle: "Remove the current album?", message: "This will permanently remove the album from the SharedImages app on your device(s). If images have been stored in your cloud storage, they will still be in your cloud storage.", allowCancel: true, okCompletion: {
        
            // TODO: Don't have any kind of spinner for this yet...
            
            do {
                try SyncServer.session.removeFromSharingGroup(sharingGroupUUID: self.sharingGroup.sharingGroupUUID)
                try SyncServer.session.sync(sharingGroupUUID: self.sharingGroup.sharingGroupUUID)
            } catch (let error) {
                Log.error("\(error)")
                SMCoreLib.Alert.show(fromVC: self, withTitle: "Alert!", message: "Could not remove the current album! Please try again later.")
                return
            }
            
            // The delegate removes references/files to the images/discussions.
            self.navigationController?.popViewController(animated: true)
        })
    }
    
    @objc private func backAction() {
        navigationController?.popViewController(animated: true)
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
        
        navigationItem.rightBarButtonItems = [otherActionBarButton!, sortFilter]
    }
    
    @objc private func sortFilterAction() {
        SortyFilter.show(fromParentVC: self, delegate: self)
    }
    
    func remove(images:[Image]) {
        // The sync/remote remove must happen before the local remove-- or we lose the reference!
        
        // 11/26/17; I got an error here "fileAlreadyDeleted". https://github.com/crspybits/SharedImages/issues/56-- `syncController.remove` failed.
        if !imagesHandler.syncController.remove(images: images, sharingGroupUUID: sharingGroup.sharingGroupUUID) {
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
        
        setupHandlers()
        
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
        
        if initialSync {
            initialSync = false
            refresh()
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // https://github.com/crspybits/SharedImages/issues/121 (a)
        bottomRefresh.hide()
    }
    
    @objc private func consistencyCheckAction(gesture : UILongPressGestureRecognizer!) {
        if gesture.state != .ended {
            return
        }
        
        let uuids = Image.fetchAll().map { $0.uuid! }
        do {
            try SyncServer.session.consistencyCheck(sharingGroupUUID: sharingGroup.sharingGroupUUID, localFiles: uuids, repair: false) { error in }
        } catch (let error) {
            SMCoreLib.Alert.show(fromVC: self, withTitle: "Problem in consistency check", message: "\(error)")
        }
    }
    
    @objc private func refresh() {
        self.refreshControl.endRefreshing()
        
        do {
            try imagesHandler.syncController.sync(sharingGroupUUID: sharingGroup.sharingGroupUUID)
        } catch (let error) {
            SMCoreLib.Alert.show(fromVC: self, withTitle: "Could not sync", message: "\(error)")
        }
    }
    
    // Enable a reset from error when needed.
    @objc private func spinnerTapGestureAction() {
        Log.msg("spinner tapped")
        refresh()
    }
    
    private func createEmptyDiscussion(image:Image, discussionUUID: String, sharingGroupUUID: String, imageTitle: String?) -> FileData? {
        let newDiscussionFileURL = ImageExtras.newJSONFile()
        var fixedObjects = FixedObjects()
        
        // This is so that we have the possibility of reconstructing the image/discussions if we lose the server data. This will explicitly connect the discussion to the image.
        // [1] It is important to note that we are *never* depending on this UUID value in app operation. This is more of a comment. While unlikely, it is possible that a user could modify this value in a discussion JSON file in cloud storage. Thus, it has unreliable contents in some real sense. See also https://github.com/crspybits/SharedImages/issues/145
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
        
        return FileData(url: newDiscussionFileURL, mimeType: .text, fileUUID: discussionUUID, sharingGroupUUID: sharingGroupUUID, gone: nil)
    }
    
    private func shareAction() {
        var alert:UIAlertController
        
        if SignInManager.session.userIsSignedIn {
            alert = UIAlertController(title: "Share album images with a Dropbox, Facebook, or Google user?", message: nil, preferredStyle: .actionSheet)

            func addAlertAction(_ permission:Permission) {
                alert.addAction(UIAlertAction(title: permission.userFriendlyText(), style: .default){alert in
                    self.completeSharing(permission: permission)
                })
            }
            
            addAlertAction(.read)
            addAlertAction(.write)
            addAlertAction(.admin)

            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel){alert in
            })
        }
        else {
            alert = UIAlertController(title: "Please sign in first!", message: "There is no signed in user.", preferredStyle: .actionSheet)
            alert.addAction(UIAlertAction(title: "OK", style: .cancel){alert in
            })
        }
        
        Alert.styleForIPad(alert)
        alert.popoverPresentationController?.barButtonItem = otherActionBarButton
        present(alert, animated: true, completion: nil)
    }
    
    private func completeSharing(permission:Permission) {
        SyncServerUser.session.createSharingInvitation(withPermission: permission, sharingGroupUUID: sharingGroup.sharingGroupUUID) { invitationCode, error in
            if error == nil {
                let sharingURLString = SharingInvitation.createSharingURL(invitationCode: invitationCode!, permission:permission)
                if let email = SMEmail(parentViewController: self) {
                    let message = "I'd like to share an album of images with you through the Neebla app and your Dropbox, Facebook, or Google account. To share images, you need to:\n" +
                        "1) download the Neebla iOS app onto your iPhone or iPad,\n" +
                        "2) tap the link below in the Apple Mail app, and\n" +
                        "3) follow the instructions within the app to sign in to your Dropbox, Facebook, or Google account.\n" +
                        "You will have " + permission.userFriendlyText() + " access to images.\n\n" +
                            sharingURLString
                    
                    email.setMessageBody(message, isHTML: false)
                    email.setSubject("Share images using the Neebla app")
                    email.show()
                }
            }
            else {
                let alert = UIAlertController(title: "Error creating sharing invitation!", message: "\(error!)", preferredStyle: .actionSheet)
                alert.popoverPresentationController?.barButtonItem = self.otherActionBarButton
                Alert.styleForIPad(alert)

                alert.addAction(UIAlertAction(title: "OK", style: .cancel) {alert in
                })
                self.present(alert, animated: true, completion: nil)
            }
        }
    }
}

extension ImagesVC : UICollectionViewDelegate {
    private func errorDetails(readProblem: Bool, gone: GoneReason?) -> String? {
        var details: String?
        
        if readProblem {
            details = "The file was corrupted in cloud storage."
        }
        else if let gone = gone {
            switch gone {
            case .userRemoved:
                details = "The owning user was removed."
            case .authTokenExpiredOrRevoked:
                details = "The authorization token for the owning user expired or was revoked."
            case .fileRemovedOrRenamed:
                details = "The cloud storage file was renamed or removed."
            }
        }
        
        return details
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let imageObj = self.coreDataSource.object(at: indexPath) as! Image
        if imageObj.eitherHasError {
            let cell = collectionView.cellForItem(at: indexPath)
            
            var title = "A file had an error when synchronizing"
            if let details = errorDetails(readProblem: imageObj.readProblem, gone:  imageObj.gone) {
                title += ": " + details
            }
            else if let discussion = imageObj.discussion, let details = errorDetails(readProblem: discussion.readProblem, gone:  discussion.gone) {
                title += ": " + details
            }
            
            let alert = UIAlertController(title: title, message: "Do you want to retry synchronizing this album?", preferredStyle: .actionSheet)
            alert.popoverPresentationController?.sourceView = cell
            Alert.styleForIPad(alert)

            alert.addAction(UIAlertAction(title: "Retry", style: .default) {alert in
                let images = Image.fetchAll()
                images.forEach { image in
                    if self.sharingGroup.sharingGroupUUID == image.sharingGroupUUID && image.readProblem {
                        try! SyncServer.session.requestDownload(forFileUUID: image.uuid!)
                    }
                }
                
                let discussions = Discussion.fetchAll()
                discussions.forEach { discussion in
                    if self.sharingGroup.sharingGroupUUID == discussion.sharingGroupUUID && discussion.readProblem {
                        try! SyncServer.session.requestDownload(forFileUUID: discussion.uuid!)
                    }
                }
                
                try! SyncServer.session.sync(sharingGroupUUID: self.sharingGroup.sharingGroupUUID, reAttemptGoneDownloads: true)
            })
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) {alert in
            })
            self.present(alert, animated: true, completion: nil)
        }
        else {
            let largeImages = storyboard!.instantiateViewController(withIdentifier: "LargeImages") as! LargeImages
            largeImages.startImage = coreDataSource.object(at: indexPath) as? Image
            largeImages.imagesHandler = imagesHandler
            largeImages.sharingGroup = sharingGroup
            navigatedToLargeImages = true
            navigationController!.pushViewController(largeImages, animated: true)
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        (cell as! ImageCollectionVC).cellSizeHasBeenChanged()
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
        cell.setProperties(image: imageObj, syncController: imagesHandler.syncController, cache: imageCache)
        
        showSelectedState(imageUUID: imageObj.uuid!, cell: cell, error: imageObj.eitherHasError)

        return cell
    }
}

extension ImagesVC : AcquireImagesDelegate {
    func acquireImagesURLForNewImage(_ acquireImages: AcquireImages) -> URL {
        return FileExtras().newURLForImage() as URL
    }
    
    func acquireImages(_ acquireImages: AcquireImages, images: [(newImageURL: URL, mimeType: String)]) {
        // There was a crash here when I force unwrapped both of these. Not sure how. I've changed to to optional chaining. See https://github.com/crspybits/SharedImages/issues/57 We'll get an empty/nil title in that case.
        let userName = SignInManager.session.currentSignIn?.credentials?.username
        if userName == nil {
            Log.error("userName was nil: SignInManager.session.currentSignIn: \(String(describing: SignInManager.session.currentSignIn)); SignInManager.session.currentSignIn?.credentials: \(String(describing: SignInManager.session.currentSignIn?.credentials))")
        }
        
        var imageAndDiscussions = [(image: Image, discussion: Discussion)]()
        
        func cleanup() {
            for current in imageAndDiscussions {
                // Also removes discussion.
                try? current.image.remove()
            }
            
            CoreData.sessionNamed(CoreDataExtras.sessionName).saveContext()
        }
        
        for newImage in images {
            guard let url = newImage.newImageURL as? SMRelativeLocalURL else {
                SMCoreLib.Alert.show(fromVC: self, withTitle: "Alert!", message: "Problem converting URL!")
                cleanup()
                return
            }
            
            guard let imageAndDiscussion = createImageAndDiscussion(newImageURL: url, mimeType: newImage.mimeType, userName: userName) else {
                SMCoreLib.Alert.show(fromVC: self, withTitle: "Alert!", message: "Problem creating image and discussion!")
                cleanup()
                return
            }
            
            imageAndDiscussions += [imageAndDiscussion]
        }
        
        scrollIfNeeded(animated:true)
        
        // Sync these new images & discussions with the server.
        imagesHandler.syncController.add(imageAndDiscussions: imageAndDiscussions, errorCleanup: cleanup)
    }
    
    private func createImageAndDiscussion(newImageURL: SMRelativeLocalURL, mimeType:String, userName: String?) -> (image: Image, discussion: Discussion)? {
        guard let mimeTypeEnum = MimeType(rawValue: mimeType) else {
            SMCoreLib.Alert.show(fromVC: self, withTitle: "Alert!", message: "Unknown mime type: \(mimeType)")
            return nil
        }
        
        guard let newDiscussionUUID = UUID.make(), let fileGroupUUID = UUID.make() else {
            SMCoreLib.Alert.show(fromVC: self, withTitle: "Alert!", message: "Could not create  UUID(s)")
            return nil
        }
        
        let imageFileData = FileData(url: newImageURL, mimeType: mimeTypeEnum, fileUUID: nil, sharingGroupUUID: sharingGroup.sharingGroupUUID, gone: nil)
        let imageData = ImageData(file: imageFileData, title: userName, creationDate: nil, discussionUUID: newDiscussionUUID, fileGroupUUID: fileGroupUUID)
        
        // We're making an image that the user of the app added-- we'll generate a new UUID.
        let newImage = imagesHandler.addOrUpdateLocalImage(newImageData: imageData, fileGroupUUID:fileGroupUUID)
        newImage.sharingGroupUUID = sharingGroup.sharingGroupUUID
        
        guard let newDiscussionFileData = createEmptyDiscussion(image: newImage, discussionUUID: newDiscussionUUID, sharingGroupUUID: sharingGroup.sharingGroupUUID, imageTitle: userName) else {
            try? newImage.remove()
            CoreData.sessionNamed(CoreDataExtras.sessionName).saveContext()
            return nil
        }
        
        let newDiscussion = imagesHandler.addToLocalDiscussion(discussionData: newDiscussionFileData, type: .newLocalDiscussion, fileGroupUUID: fileGroupUUID)
        newDiscussion.sharingGroupUUID = sharingGroup.sharingGroupUUID
        
        return (newImage, newDiscussion)
    }
}

extension ImagesVC : CoreDataSourceDelegate {
    // This must have sort descriptor(s) because that is required by the NSFetchedResultsController, which is used internally by this class.
    func coreDataSourceFetchRequest(_ cds: CoreDataSource!) -> NSFetchRequest<NSFetchRequestResult>! {
        let params = Image.SortFilterParams(sortingOrder: Parameters.sortingOrder, isAscending: Parameters.sortingOrderIsAscending, unreadCounts: Parameters.unreadCounts, sharingGroupUUID: sharingGroup.sharingGroupUUID, includeErrors: true)
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

extension ImagesVC /* ImagesHandler */ {
    func syncEvent(event:SyncControllerEvent) {
        switch event {
        case .syncDelayed:
            // Trying to deal with https://github.com/crspybits/SharedImages/issues/126
            self.bottomRefresh.hide()
            
        case .syncStarted:
            // Put this hide here (instead of in syncDone) to try to deal with https://github.com/crspybits/SharedImages/issues/121 (c)
            self.bottomRefresh.hide()
            
        case .syncDone (let numberOperations):
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
            
        case .syncServerDown:
            self.bottomRefresh.hide()
        }
    }
    
    func completedAddingOrUpdatingLocalImages() {
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
        // Seems like the crash Dany was getting was here: https://github.com/crspybits/SharedImages/issues/123
        let image = self.coreDataSource.object(at: indexPath) as! Image
        
        guard let imageOriginalSize = image.originalSize else {
            return boundingCellSize
        }
        
        let boundedImageSize = ImageExtras.boundingImageSizeFor(originalSize: imageOriginalSize, boundingSize: boundingCellSize)

        return CGSize(width: boundedImageSize.width, height: boundedImageSize.height + ImageCollectionVC.smallTitleHeight)
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumLineSpacingForSectionAt section: Int) -> CGFloat {
        return 10.0
    }
}

// MARK: Sharing and deletion activity.
extension ImagesVC {
    // For sharing images via email, text messages, and for deleting images.
    @objc fileprivate func actionButtonAction() {
        // Create an array containing both UIImage's and Image's. The UIActivityViewController will use the UIImage's. The TrashActivity will use the Image's.
        var images = [Any]()
        for uuidString in selectedImages {
            if let imageObj = Image.fetchObjectWithUUID(uuidString) {
                if !imageObj.readProblem, let url = imageObj.url {
                    let uiImage = ImageExtras.fullSizedImage(url: url as URL)
                    images.append(uiImage)
                }
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
                
                // Allowing selection of an image even when there is an error, such as image.hasError -- e.g., so that deletion can be allowed. Will have to, downstream, disable certain operations-- such as sending the image to someone, if there is no image.
                
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
    
    fileprivate func showSelectedState(imageUUID:String, cell:UICollectionViewCell, error: Bool = false) {
        if let cell = cell as? ImageCollectionVC {
            if error {
                cell.userSelected = false
            }
            else {
                cell.userSelected = selectedImages.contains(imageUUID)
            }
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
