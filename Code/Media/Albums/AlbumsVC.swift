//
//  AlbumsVC.swift
//  SharedImages
//
//  Created by Christopher G Prince on 9/29/18.
//  Copyright © 2018 Spastic Muffin, LLC. All rights reserved.
//

import UIKit
import SMCoreLib
import SyncServer
import ODRefreshControl
import NVActivityIndicatorView
import SDCAlertView

private class FlowLayout: UICollectionViewFlowLayout {
    var viewSize: CGSize!
}

class AlbumsVC: UIViewController, NVActivityIndicatorViewable {
    @IBOutlet weak var collectionView: UICollectionView!
    let reuseIdentifier = "CollectionViewCell"
    let numberOfItemsPerRow = 2
    private var sharingGroups:[SyncServer.SharingGroup]!

    // Sets up delegate for SyncServer also.
    private var mediaHandler:MediaHandler {
        return MediaHandler.session
    }
    
    private var shouldLayoutSubviews = true
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    private var addAlbum:UIBarButtonItem!
    private var shareAlbums:UIBarButtonItem!
    @IBOutlet weak var collectionViewBottom: NSLayoutConstraint!
    private var originalCollectionViewBottom: CGFloat!
    
    // To enable pulling down on the table view to initiate a sync with server. This spinner is displayed only momentarily, but you can always do the pull down to sync/refresh.
    var refreshControl:ODRefreshControl!
    
    private var sharingOn: Bool = false {
        didSet {
            if sharingOn {
                shareAlbums.tintColor = .lightGray
            }
            else {
                shareAlbums.tintColor = nil
            }
        }
    }
    
    private var shareAlbum:ShareAlbum!
    
    static func create() -> AlbumsVC {
        return UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "AlbumsVC") as! AlbumsVC
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        
        title = "Albums"
        
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardChangeFrameAction), name: UIResponder.keyboardWillChangeFrameNotification, object: nil)
        
        // To manually refresh-- pull down on collection view.
        refreshControl = ODRefreshControl.create(scrollView: collectionView, nav: navigationController!, target: self, selector: #selector(refresh))
        
        // We need this for the refresh.
        collectionView.alwaysBounceVertical = true
        
        addAlbum = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(addAlbumAction))
        shareAlbums = UIBarButtonItem(image: #imageLiteral(resourceName: "Share"), style: .plain, target: self, action: #selector(shareAction))
        setupBarButtonItems()
        
        // Because, when app enters background, AppBadge sets itself up to use handlers.
        NotificationCenter.default.addObserver(self, selector:#selector(setupHandlers), name:
            UIApplication.willEnterForegroundNotification, object: nil)
    }
    
    private func setupBarButtonItems(canShareAlbum: Bool = false) {
        if canShareAlbum {
            navigationItem.rightBarButtonItems = [addAlbum, shareAlbums]
        }
        else {
            navigationItem.rightBarButtonItems = [addAlbum]
        }
    }
    
    @objc private func shareAction() {
        sharingOn = !sharingOn
        collectionView.reloadData()
    }
    
    @objc private func setupHandlers() {
        mediaHandler.syncEventAction = syncEvent
        mediaHandler.completedAddingOrUpdatingLocalMediaAction = nil
    }
    
    @objc private func refresh() {
        self.refreshControl.endRefreshing()
        startActivityIndicator()
        Log.info("About to do refresh sync")
        do {
            try SyncServer.session.sync()
        } catch (let error) {
            SMCoreLib.Alert.show(fromVC: self, withTitle: "Could not sync", message: "\(error)")
        }
    }
    
    @objc private func keyboardChangeFrameAction(notification:NSNotification) {
        guard let windowView = view.window else {
            return
        }
        
        let kbFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as! CGRect
        let kbWindowIntersectionFrame = windowView.bounds.intersection(kbFrame)
        let showingKeyboard = windowView.bounds.intersects(kbFrame)
        let duration = notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as! Double
        
        if showingKeyboard && originalCollectionViewBottom == collectionViewBottom.constant || !showingKeyboard {
            // If the bottom of the scroll view will be above the keyboard, then we don't need this adjustment. This can happen in certain rotations on iPad.
            // Need to figure out the bottom coordinates of the scrollView in terms of the view.
            let convertedScrollViewOrigin = collectionView.superview!.convert(collectionView.frame.origin, to: view.window!)
            let convertedScrollViewBottom = convertedScrollViewOrigin.y + collectionView.frame.height
            let distanceFromBottomForScrollView = windowView.bounds.height - convertedScrollViewBottom
            
            let adjustedIntersectionHeight = max(kbWindowIntersectionFrame.size.height - distanceFromBottomForScrollView, 0)
            collectionViewBottom.constant = adjustedIntersectionHeight
            
            UIView.animate(withDuration: duration) {
                self.collectionView.superview!.layoutIfNeeded()
            }
        }
    }
    
    @objc private func addAlbumAction() {
        guard !sharingOn else {
            return
        }
        
        if SignInManager.session.currentSignIn?.userType == .sharing {
            SMCoreLib.Alert.show(fromVC: self, withTitle: "Alert!", message: "Users without cloud storage cannot create sharing groups.")
            return
        }
        
        let alert = AlertController(title: "Confirmation", message: "Do you want to create a new album?", preferredStyle: AlertController.prominentStyle())
        alert.popoverPresentationController?.barButtonItem = addAlbum
        alert.behaviors = [.dismissOnOutsideTap]
        alert.addAction(AlertAction(title: "Cancel", style: .preferred) {[unowned self] alert in
            self.dismiss(animated: true, completion: nil)
        })
        alert.addAction(AlertAction(title: "Create", style: .normal) { alert in
            let newSharingGroupUUID = UUID().uuidString
            do {
                try SyncServer.session.createSharingGroup(sharingGroupUUID: newSharingGroupUUID)
                try SyncServer.session.sync(sharingGroupUUID: newSharingGroupUUID)
            } catch (let error) {
                Log.info("\(error)")
                SMCoreLib.Alert.show(fromVC: self, withTitle: "Alert!", message: "Could not add album. Please try again later.")
            }
        })
        
        present(alert, animated: true, completion: nil)
    }
    
    private func startActivityIndicator() {
        let minDisplayTimeMilliseconds = 300
        let size = CGSize(width: 50, height: 50)
        let indicatorType:NVActivityIndicatorType = .lineSpinFadeLoader
        startAnimating(size, message: "Syncing...", type: indicatorType, minimumDisplayTime: minDisplayTimeMilliseconds, fadeInAnimation: nil)
    }
    
    private func stopActivityIndicator() {
        stopAnimating(nil)
    }
    
    private func syncEvent(event: SyncControllerEvent) {
        switch event {
        case .syncDelayed:
            stopActivityIndicator()
            
        case .syncDone(numberOperations: _):
            stopActivityIndicator()
            updateSharingGroups()
            Progress.session.finish()
            
        case .syncError(message: let message):
            stopActivityIndicator()
            SMCoreLib.Alert.show(fromVC: self, withTitle: "Alert!", message: "An error occurred: \(message)")
            
        case .syncStarted:
            break
            
        case .syncServerDown:
            stopActivityIndicator()
        }
    }
    
    private func updateSharingGroups() {
        sharingGroups = SyncServer.session.sharingGroups

        sharingGroups.sort { sg1, sg2 in
            if let name1 = sg1.sharingGroupName, let name2 = sg2.sharingGroupName {
                return name1 < name2
            }
            return true
        }
        
        let adminGroups = sharingGroups.filter { $0.permission.hasMinimumPermission(.admin)}
        setupBarButtonItems(canShareAlbum: adminGroups.count > 0)

        // Can't seem to do this with `performBatchUpdates` to get animations. It crashes.
        collectionView.reloadData()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Put these here because the ImagesVC changes them.
        setupHandlers()
        
        // So, when we return from another screen we're not in the sharing state.
        // updateSharingGroups, below, does a collection view reload-- so this will get used.
        sharingOn = false
        
        // Putting this in `viewWillAppear` to deal with the first time the Albums are displayed and to deal with removal of an album in ImagesVC. And to deal with sharing group updates from other places in the app.
        updateSharingGroups()
        
        Progress.session.viewController = self
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        if SharingInviteDelegate.invitationRedeemed {
            SharingInviteDelegate.invitationRedeemed = false
            
            startActivityIndicator()
            Log.info("About to do AlbumsVC.viewDidAppear sync")
            do {
                try SyncServer.session.sync()
            } catch (let error) {
                SMCoreLib.Alert.show(fromVC: self, withTitle: "Could not sync", message: "\(error)")
            }
        }
        
        Notifications.checkForNotificationAuthorization(usingViewController: self)
    }
    
    private func layoutSubviews() {
        collectionView.dataSource = self
        collectionView.delegate = self
        let layout = FlowLayout()
        layout.viewSize = collectionView.boundsSize
        layout.sectionInset = UIEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)
        collectionView.collectionViewLayout = layout
        collectionView.register(UICollectionViewCell.self, forCellWithReuseIdentifier: reuseIdentifier)
        originalCollectionViewBottom = collectionViewBottom.constant
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        if shouldLayoutSubviews {
            shouldLayoutSubviews = false
            layoutSubviews()
        }
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        
        // To resize cells when we rotate the device.
        // 9/10/18; Got a crash here on accepting an invitation because self.collectionView was nil.
        if let flowLayout = self.collectionView?.collectionViewLayout as? FlowLayout {
            flowLayout.viewSize = size
            flowLayout.invalidateLayout()
        }
    }
    
    private func saveNewSharingGroupName(sharingGroupUUID: String, newName: String) {
        do {
            startActivityIndicator()
            try SyncServer.session.updateSharingGroup(sharingGroupUUID: sharingGroupUUID, newSharingGroupName: newName)
            try SyncServer.session.sync(sharingGroupUUID: sharingGroupUUID)
        } catch (let error) {
            stopActivityIndicator()
            Log.info("\(error)")
            SMCoreLib.Alert.show(fromVC: self, withTitle: "Alert!", message: "Could not change album name. Please try again later.")
        }
    }
}

extension AlbumsVC : UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
    }
}

extension AlbumsVC : UICollectionViewDataSource {
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return sharingGroups.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: reuseIdentifier, for: indexPath)
        let sharingGroup = sharingGroups[indexPath.row]
        
        var albumCell: AlbumCell!
        if cell.contentView.subviews.count > 0,
            let ac = cell.contentView.subviews[0] as? AlbumCell {
            albumCell = ac
        }
        else {
            albumCell = AlbumCell.create()!
            cell.contentView.addSubview(albumCell)
            albumCell.frameSize = cell.contentView.frameSize
            
            // This is critical or we get really odd cell-sizing behavior in rotation of the device.
            albumCell.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        }

        let sharingReallyOn = sharingGroup.permission.hasMinimumPermission(.admin) && sharingOn

        func tapAction(initialSync: Bool = false) {
            unowned let unownedSelf = self
            if sharingOn {
                if sharingReallyOn {
                    // Before starting the sharing process, briefly flash the sharing icon to show user that they're selecting the specific album.
                    albumCell.flashSharingIcon { [unowned self] in
                        unownedSelf.shareAlbum = ShareAlbum(sharingGroup: sharingGroup, fromView: albumCell, viewController: self, sharingButton: self.shareAlbums)
                        unownedSelf.sharingOn = false
                        unownedSelf.collectionView.reloadData()
                        unownedSelf.shareAlbum.start()
                    }
                }
            }
            else {
                unownedSelf.gotoAlbum(sharingGroup: sharingGroup, initialSync: initialSync)
            }
        }
        
        albumCell.setup(sharingGroup: sharingGroup, enableGroupNameEditing: sharingGroup.permission.hasMinimumPermission(.write), sharingOn: sharingOn, sharingReallyOn: sharingReallyOn)
        albumCell.tapAction = {
            tapAction()
        }
        albumCell.albumSyncAction = {
            tapAction(initialSync: true)
        }
        albumCell.saveAction = {[unowned self] newName in
            self.saveNewSharingGroupName(sharingGroupUUID: sharingGroup.sharingGroupUUID, newName: newName)
        }
        albumCell.startEditing = {[unowned self] in
            self.addAlbum.isEnabled = false
        }
        albumCell.endEditing = {[unowned self] in
            self.addAlbum.isEnabled = true
        }
        
        return cell
    }
    
    private func gotoAlbum(sharingGroup: SyncServer.SharingGroup, initialSync: Bool=false) {
        let vc = MediaVC.create()
        vc.sharingGroup = sharingGroup
        vc.mediaHandler = self.mediaHandler
        vc.initialSync = initialSync
        self.navigationController?.pushViewController(vc, animated: true)
    }
}

extension AlbumsVC: UICollectionViewDelegateFlowLayout {
    // From https://stackoverflow.com/questions/14674986/uicollectionview-set-number-of-columns
    func collectionView(_ collectionView: UICollectionView,
        layout collectionViewLayout: UICollectionViewLayout,
        sizeForItemAt indexPath: IndexPath) -> CGSize {
        
        let flowLayout = collectionViewLayout as! FlowLayout
        let totalSpace = flowLayout.sectionInset.left
                + flowLayout.sectionInset.right
                + (flowLayout.minimumInteritemSpacing * CGFloat(numberOfItemsPerRow - 1))
        let size = (flowLayout.viewSize.width - totalSpace) / CGFloat(numberOfItemsPerRow)
        
        return CGSize(width: size, height: size)
    }
}
