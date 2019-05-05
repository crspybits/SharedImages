//
//  MediaVC.swift
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

class MediaVC: UIViewController {
    // Set these before showing screen.
    var sharingGroup: SyncServer.SharingGroup!
    var mediaHandler: MediaHandler!
    var initialSync = false
    
    let reuseIdentifier = "ImageIcon"
    var addImagesButton:UIBarButtonItem!
    var coreDataSource:CoreDataSource!
    
    // To enable pulling down on the table view to initiate a sync with server. This spinner is displayed only momentarily, but you can always do the pull down to sync/refresh.
    var refreshControl:ODRefreshControl!
    
    @IBOutlet weak var collectionView: UICollectionView!
    
    fileprivate var navigatedToLargeMedia = false
    
    fileprivate var imageCache:LRUCache<ImageMediaObject>! {
        return ImageExtras.imageCache
    }

    private var bottomRefresh:BottomRefresh!
    
    // To allow user to select images for sending via text messages, email (etc), or for deletion.
    typealias UUIDString = String
    fileprivate var selectedImages = Set<UUIDString>()
    
    private var deletedImages:[IndexPath]?
    private var noDownloadImageView:UIImageView!
    private let titleLabel = ImagesTitle.create()!
    
    private var selectionOn = false {
        didSet {
            if selectionOn {
                selectImages.tintColor = .lightGray
                selectedImages.removeAll()
            }
            else {
                selectImages.tintColor = nil
                navigationController?.setToolbarHidden(true, animated: true)
            }
        }
    }
    
    private var removeImages:RemoveImages!
    private var selectImages:UIButton!
    private var mediaSelector:MediaSelectorVC!
    
    static func create() -> MediaVC {
        return UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "MediaVC") as! MediaVC
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // These are for the toolbar that appears when you've entered the "Selection" state (selectionOn == true).
        let action = UIBarButtonItem(barButtonSystemItem: .action, target: self, action: #selector(actionButtonAction))
        let trash = UIBarButtonItem(barButtonSystemItem: .trash, target: self, action: #selector(removeImagesAction))
        let flexSpace = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        setToolbarItems([action, flexSpace, trash], animated: false)

        collectionView.dataSource = self
        collectionView.delegate = self
        
        coreDataSource = CoreDataSource(delegate: self)
        
        // To manually refresh-- pull down on collection view.
        refreshControl = ODRefreshControl.create(scrollView: collectionView, nav: navigationController!, target: self, selector: #selector(refresh))
        
        collectionView.alwaysBounceVertical = true
        
        titleLabel.title.text = sharingGroup.sharingGroupName ?? "Album Images"
        titleLabel.buttonAction = { [unowned self] in
            self.sortFilterAction()
        }
        titleLabel.updateCaret()
        navigationItem.titleView = titleLabel
        
        selectImages = UIButton(type: .system)
        selectImages.setImage(#imageLiteral(resourceName: "Select"), for: .normal)
        selectImages.addTarget(self, action: #selector(selectImagesAction), for: .touchUpInside)
        let selectImagesBarButton = UIBarButtonItem(customView: selectImages)
        
        if sharingGroup.permission.hasMinimumPermission(.write) {
            addImagesButton = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(addImagesAction))
            navigationItem.rightBarButtonItems = [addImagesButton, selectImagesBarButton]
        }
        else {
            navigationItem.rightBarButtonItems = [selectImagesBarButton]
        }
        
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
        
        bottomRefresh = BottomRefresh(withScrollView: collectionView, scrollViewParent: view, refreshAction: { [unowned self] in
            Log.info("bottomRefresh: starting sync")
            do {
                try self.mediaHandler.syncController.sync(sharingGroupUUID: self.sharingGroup.sharingGroupUUID)
            } catch (let error) {
                SMCoreLib.Alert.show(fromVC: self, withTitle: "Could not sync", message: "\(error)")
            }
        })
    }
    
    @objc private func removeImagesAction() {
        var images = [ImageMediaObject]()
        for uuidString in selectedImages {
            if let imageObj = ImageMediaObject.fetchObjectWithUUID(uuidString) {
                images.append(imageObj as! ImageMediaObject)
            }
        }
        
        removeImages = RemoveImages(images, syncController: mediaHandler.syncController, sharingGroup: sharingGroup, withParentVC: self)
        removeImages.start() {[unowned self] in
            self.selectionOn = false
        }
    }
    
    @objc private func addImagesAction() {
        guard !selectionOn else {
            return
        }
        
        mediaSelector = MediaSelectorVC.show(fromParentVC: self, imageDelegate: self, urlPickerDelegate: self)
    }
    
    @objc private func selectImagesAction() {
        selectionOn = !selectionOn
        
        for indexPath in collectionView.indexPathsForVisibleItems {
            let mediaObj = coreDataSource.object(at: indexPath) as! FileMediaObject
            let cell = self.collectionView.cellForItem(at: indexPath) as! MediaCollectionViewCell
            showSelectedState(mediaUUID: mediaObj.uuid!, cell: cell)
        }
    }
    
    @objc private func setupHandlers() {
        mediaHandler.syncEventAction = syncEvent
        mediaHandler.completedAddingOrUpdatingLocalMediaAction = completedAddingOrUpdatingLocalImages
    }
    
    @objc private func backAction() {
        navigationController?.popViewController(animated: true)
    }
    
    @objc private func sortFilterAction() {
        SortyFilter.show(fromParentVC: self, delegate: self)
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
        // And to reset selections if selectionOn = true and selections made before navigating away.
        collectionView.reloadData()
        
        Progress.session.viewController = self
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        // If we navigated to the large media and are just coming back now, don't bother with the scrolling.
        if navigatedToLargeMedia {
            navigatedToLargeMedia = false
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
        
        selectionOn = false
    }

    @objc private func refresh() {
        self.refreshControl.endRefreshing()
        
        do {
            try mediaHandler.syncController.sync(sharingGroupUUID: sharingGroup.sharingGroupUUID)
        } catch (let error) {
            SMCoreLib.Alert.show(fromVC: self, withTitle: "Could not sync", message: "\(error)")
        }
    }
    
    // Enable a reset from error when needed.
    @objc private func spinnerTapGestureAction() {
        Log.info("spinner tapped")
        refresh()
    }
    
    func createEmptyDiscussion(media:FileMediaObject, discussionUUID: String, sharingGroupUUID: String, mediaTitle: String?) -> FileData? {
        let newDiscussionFileURL = Files.newJSONFile()
        var fixedObjects = FixedObjects()
        
        // This is so that we have the possibility of reconstructing the media/discussions if we lose the server data. This will explicitly connect the discussion to the media.
        // [1] It is important to note that we are *never* depending on this UUID value in app operation. This is more of a comment. While unlikely, it is possible that a user could modify this value in a discussion JSON file in cloud storage. Thus, it has unreliable contents in some real sense. See also https://github.com/crspybits/SharedImages/issues/145
        fixedObjects[DiscussionKeys.mediaUUIDKey] = media.uuid
        
        // 4/17/18; Media titles are now stored in the "discussion" file. This may reduce the amount of data we need store in the server database.
        fixedObjects[DiscussionKeys.mediaTitleKey] = mediaTitle

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
    
    func getUsername() -> String? {
        // There was a crash here when I force unwrapped both of these. Not sure how. I've changed to to optional chaining. See https://github.com/crspybits/SharedImages/issues/57 We'll get an empty/nil title in that case.
        let userName = SignInManager.session.currentSignIn?.credentials?.username
        if userName == nil {
            Log.error("userName was nil: SignInManager.session.currentSignIn: \(String(describing: SignInManager.session.currentSignIn)); SignInManager.session.currentSignIn?.credentials: \(String(describing: SignInManager.session.currentSignIn?.credentials))")
        }
        
        return userName
    }
}

extension MediaVC : UICollectionViewDelegate {
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
        guard !selectionOn else {
            selectImage(atIndexPath: indexPath)
            return
        }
        
        guard let mediaObj = self.coreDataSource.object(at: indexPath) as? FileMediaObject else {
            return
        }
        
        if mediaObj.eitherHasError {
            let cell = collectionView.cellForItem(at: indexPath)
            
            var title = "A file had an error when synchronizing"
            if let details = errorDetails(readProblem: mediaObj.readProblem, gone:  mediaObj.gone) {
                title += ": " + details
            }
            else if let discussion = mediaObj.discussion,
                let details = errorDetails(readProblem: discussion.readProblem, gone:  discussion.gone) {
                title += ": " + details
            }
            
            let alert = UIAlertController(title: title, message: "Do you want to retry synchronizing this album?", preferredStyle: .alert)
            alert.popoverPresentationController?.sourceView = cell
            Alert.styleForIPad(alert)

            alert.addAction(UIAlertAction(title: "Retry", style: .default) {alert in
                // TODO: This seems inefficient...
                let media = FileMediaObject.fetchAllAbstractObjects()
                media.forEach { aMedia in
                    if self.sharingGroup.sharingGroupUUID == aMedia.sharingGroupUUID && aMedia.readProblem {
                        try! SyncServer.session.requestDownload(forFileUUID: aMedia.uuid!)
                    }
                }
                
                let discussions = DiscussionFileObject.fetchAll()
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
            let largeMedia = LargeMediaVC.create()
            largeMedia.startMedia = coreDataSource.object(at: indexPath) as? FileMediaObject
            largeMedia.mediaHandler = mediaHandler
            largeMedia.sharingGroup = sharingGroup
            navigatedToLargeMedia = true
            navigationController!.pushViewController(largeMedia, animated: true)
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        (cell as! MediaCollectionViewCell).cellSizeHasBeenChanged()
    }
}

// MARK: UICollectionViewDataSource
extension MediaVC : UICollectionViewDataSource {
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return Int(coreDataSource.numberOfRows(inSection: 0))
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: reuseIdentifier, for: indexPath) as! MediaCollectionViewCell
        
        if let mediaObj = self.coreDataSource.object(at: indexPath) as? MediaType {
            cell.setProperties(media: mediaObj, syncController: mediaHandler.syncController, cache: imageCache)
            showSelectedState(mediaUUID: mediaObj.uuid!, cell: cell, error: mediaObj.eitherHasError)
        }

        return cell
    }
}

extension MediaVC : AcquireImagesDelegate {
    func acquireImagesURLForNewImage(_ acquireImages: AcquireImages) -> URL {
        return Files.newURLForImage() as URL
    }
    
    // TODO: Having problems showing alerts from here. Conflicting with possible present image capture screen.
    func acquireImages(_ acquireImages: AcquireImages, images: [(newImageURL: URL, mimeType: String)]) {
        let userName = getUsername()
        var fileObjects = [FileObject]()
        
        func cleanup() {
            for object in fileObjects {
                try? object.remove()
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
            
            fileObjects += [imageAndDiscussion.image]
            fileObjects += [imageAndDiscussion.discussion]
        }
        
        scrollIfNeeded(animated:true)
        
        // Sync these new images & discussions with the server.
        mediaHandler.syncController.add(objects:fileObjects, errorCleanup: cleanup)
    }
}

extension MediaVC : CoreDataSourceDelegate {
    // This must have sort descriptor(s) because that is required by the NSFetchedResultsController, which is used internally by this class.
    func coreDataSourceFetchRequest(_ cds: CoreDataSource!) -> NSFetchRequest<NSFetchRequestResult>! {
        let params = FileMediaObject.SortFilterParams(sortingOrder: Parameters.sortingOrder, isAscending: Parameters.sortingOrderIsAscending, unreadCounts: Parameters.unreadCounts, sharingGroupUUID: sharingGroup.sharingGroupUUID, includeErrors: true)
        return FileMediaObject.fetchRequestForAllObjects(params: params)
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
        Log.info("objectWasDeleted: indexPathOfDeletedObject: \(String(describing: indexPathOfDeletedObject))")
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

extension MediaVC /* ImagesHandler */ {
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

extension MediaVC : UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
    
        let proportion:CGFloat = 0.30
        // Estimate a suitable size for the cell. proportion*100% of the width of the collection view.
        let size = collectionView.frame.width * proportion
        let boundingCellSize = CGSize(width: size, height: size)
        
        // And then figure out how big the media will be.
        // Seems like the crash Dany was getting was here: https://github.com/crspybits/SharedImages/issues/123        
        guard let media = self.coreDataSource.object(at: indexPath) as? MediaType,
            let mediaOriginalSize = media.originalSize else {
            return boundingCellSize
        }
        
        let boundedMediaSize = ImageExtras.boundingImageSizeFor(originalSize: mediaOriginalSize, boundingSize: boundingCellSize)

        return CGSize(width: boundedMediaSize.width, height: boundedMediaSize.height + MediaCollectionViewCell.smallTitleHeight)
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumLineSpacingForSectionAt section: Int) -> CGFloat {
        return 10.0
    }
}

// MARK: Sharing and deletion activity.
extension MediaVC {
    // For sharing images via email, text messages, and for deleting images.
    @objc fileprivate func actionButtonAction() {
        // Create an array containing both UIImage's and Image's. The UIActivityViewController will use the UIImage's. The TrashActivity will use the Image's.
        var images = [Any]()
        for uuidString in selectedImages {
            if let imageObj = ImageMediaObject.fetchObjectWithUUID(uuidString) {
                if !imageObj.readProblem, let url = imageObj.url {
                    let uiImage = ImageExtras.fullSizedImage(url: url as URL)
                    images.append(uiImage)
                }
                images.append(imageObj)
            }
        }
        
        if images.count == 0 {
            Log.warning("No images selected!")
            SMCoreLib.Alert.show(withTitle:  "No usable images selected!")
            return
        }

        let activityViewController = UIActivityViewController(activityItems: images, applicationActivities: nil)
        
        activityViewController.completionWithItemsHandler = { activityType, completed, returnedItems, error in
            if completed {
                // Action has been carried out (e.g., image has been deleted), remove `Selected` icons.
                self.selectedImages.removeAll()
                self.selectionOn = false
                self.collectionView.reloadData()
            }
        }
        
        // 8/26/17; https://github.com/crspybits/SharedImages/issues/29
        activityViewController.popoverPresentationController?.sourceView = view
        
        present(activityViewController, animated: true, completion: {})
    }
    
    private func selectImage(atIndexPath indexPath: IndexPath) {
        let mediaObj = coreDataSource.object(at: indexPath) as! FileMediaObject
        
        // Allowing selection of an image even when there is an error, such as image.hasError -- e.g., so that deletion can be allowed. Will have to, downstream, disable certain operations-- such as sending the image to someone, if there is no image.
        
        if selectedImages.contains(mediaObj.uuid!) {
            // Deselect image
            selectedImages.remove(mediaObj.uuid!)
        }
        else {
            // Select image
            selectedImages.insert(mediaObj.uuid!)
        }
        
        if selectedImages.count > 0 {
            if navigationController?.isToolbarHidden == true {
                navigationController?.setToolbarHidden(false, animated: true)
            }
        }
        else {
            if navigationController?.isToolbarHidden == false {
                navigationController?.setToolbarHidden(true, animated: true)
            }
        }
        
        let cell = self.collectionView.cellForItem(at: indexPath) as! MediaCollectionViewCell
        showSelectedState(mediaUUID: mediaObj.uuid!, cell: cell)
    }
    
    fileprivate func showSelectedState(mediaUUID:String, cell:UICollectionViewCell, error: Bool = false) {
        if let cell = cell as? MediaCollectionViewCell {
            if error || !selectionOn {
                cell.selectedState = nil
            }
            else if selectedImages.contains(mediaUUID) {
                cell.selectedState = .selected
            }
            else {
                cell.selectedState = .notSelected
            }
        }
    }
}

extension MediaVC : SortyFilterDelegate {
    func sortyFilter(sortFilterByParameters: SortyFilter) {
        coreDataSource.fetchData()
        titleLabel.updateCaret()
        collectionView.reloadData()
    }
}

extension MediaVC: URLPickerDelegate {
    func urlPicker(_ picker: URLPickerVC, urlSelected: URLPickerVC.SelectedURL) {
        let userName = getUsername()
        
        var imageType: URLMediaObject.URLFileContents.ImageType?
        var image: UIImage?
        
        if let selectedImage = urlSelected.image {
            switch selectedImage {
            case .icon(let iconImage):
                imageType = .icon
                image = iconImage
            case .large(let largeImage):
                imageType = .large
                image = largeImage
            }
        }
        
        let contents = URLMediaObject.URLFileContents(url: urlSelected.data.url, title: urlSelected.data.title, imageType: imageType)
        guard let localFileURL = URLMediaObject.createLocalURLFile(contents: contents) else {
            SMCoreLib.Alert.show(fromVC: self, withTitle: "Alert!", message: "Problem creating local url file!")
            return
        }
        
        guard let urlMediaAndDiscussion = createURLMediaAndDiscussion(newMediaURL: localFileURL, mimeType: MimeType.url.rawValue, userName: userName) else {
            SMCoreLib.Alert.show(fromVC: self, withTitle: "Alert!", message: "Problem creating url media and discussion!")
            return
        }
        
        if let image = image {
            let imageLocalURL = Files.newURLForImage()
            if AcquireImages().write(image: image, to: imageLocalURL as URL) {
                let imagePreviewObject = URLPreviewImageObject.newObjectAndMakeUUID(makeUUID: true) as! URLPreviewImageObject
                urlMediaAndDiscussion.urlMedia.previewImage = imagePreviewObject
                imagePreviewObject.fileGroupUUID = urlMediaAndDiscussion.urlMedia.fileGroupUUID
                imagePreviewObject.gone = nil
                imagePreviewObject.mimeType = MimeType.jpeg.rawValue
                imagePreviewObject.sharingGroupUUID = urlMediaAndDiscussion.urlMedia.sharingGroupUUID
                imagePreviewObject.url = imageLocalURL
                imagePreviewObject.save()
            }
        }
        
        scrollIfNeeded(animated:true)
        
        func cleanup() {
            // Also removes discussion & image preview
            try? urlMediaAndDiscussion.urlMedia.remove()
            
            CoreData.sessionNamed(CoreDataExtras.sessionName).saveContext()
        }
        
        var fileObjects:[FileObject] = [urlMediaAndDiscussion.urlMedia, urlMediaAndDiscussion.discussion]
        if let imagePreview = urlMediaAndDiscussion.urlMedia.previewImage {
            fileObjects += [imagePreview]
        }
        
        // Sync this new url media, discussion, & image preview with the server.
        mediaHandler.syncController.add(objects: fileObjects, errorCleanup: cleanup)
    }
}
