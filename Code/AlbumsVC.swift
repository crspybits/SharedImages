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

class AlbumsVC: UIViewController {
    @IBOutlet weak var collectionView: UICollectionView!
    let reuseIdentifier = "CollectionViewCell"
    let numberOfItemsPerRow = 2
    private var sharingGroups:[SyncServer.SharingGroup]!

    // Sets up delegate for SyncServer also.
    private var imagesHandler:ImagesHandler {
        return ImagesHandler.session
    }
    
    private var shouldLayoutSubviews = true
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    private var addAlbum:UIBarButtonItem!
    @IBOutlet weak var collectionViewBottom: NSLayoutConstraint!
    private var originalCollectionViewBottom: CGFloat!
    
    // To enable pulling down on the table view to initiate a sync with server. This spinner is displayed only momentarily, but you can always do the pull down to sync/refresh.
    var refreshControl:ODRefreshControl!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        title = "Albums"
        
        collectionView.dataSource = self
        collectionView.delegate = self
        let layout = UICollectionViewFlowLayout()
        layout.sectionInset = UIEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)
        collectionView.collectionViewLayout = layout
        collectionView.register(UICollectionViewCell.self, forCellWithReuseIdentifier: reuseIdentifier)
        
        addAlbum = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(addAlbumAction))
        navigationItem.rightBarButtonItem = addAlbum
        
        originalCollectionViewBottom = collectionViewBottom.constant
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardChangeFrameAction), name: UIResponder.keyboardWillChangeFrameNotification, object: nil)
        
        // To manually refresh-- pull down on collection view.
        refreshControl = ODRefreshControl.create(scrollView: collectionView, nav: navigationController!, target: self, selector: #selector(refresh))
        
        // We need this for the refresh.
        collectionView.alwaysBounceVertical = true
        
        // Because, when app enters background, AppBadge sets itself up to use handlers.
        NotificationCenter.default.addObserver(self, selector:#selector(setupHandlers), name:
            UIApplication.willEnterForegroundNotification, object: nil)
    }
    
    @objc private func setupHandlers() {
        imagesHandler.syncEventAction = syncEvent
        imagesHandler.completedAddingOrUpdatingLocalImagesAction = nil
    }
    
    @objc private func refresh() {
        self.refreshControl.endRefreshing()
        
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
        if SignInManager.session.currentSignIn?.userType == .sharing {
            SMCoreLib.Alert.show(fromVC: self, withTitle: "Alert!", message: "Users without cloud storage cannot create sharing groups.")
            return
        }
        
        let alert = UIAlertController(title: "Confirmation", message: "Do you want to create a new album?", preferredStyle: .actionSheet)
        alert.popoverPresentationController?.barButtonItem = addAlbum
    
        alert.addAction(UIAlertAction(title: "Create", style: .default) { alert in
            let newSharingGroupUUID = UUID().uuidString
            do {
                try SyncServer.session.createSharingGroup(sharingGroupUUID: newSharingGroupUUID)
                try SyncServer.session.sync(sharingGroupUUID: newSharingGroupUUID)
            } catch (let error) {
                Log.msg("\(error)")
                SMCoreLib.Alert.show(fromVC: self, withTitle: "Alert!", message: "Could not add album. Please try again later.")
            }
        })
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { alert in
        })
        
        present(alert, animated: true, completion: nil)
    }
    
    private func syncEvent(event: SyncControllerEvent) {
        switch event {
        case .syncDelayed:
            activityIndicator.stopAnimating()
            
        case .syncDone(numberOperations: _):
            activityIndicator.stopAnimating()
            updateSharingGroups()
            Progress.session.finish()
            
        case .syncError(message: let message):
            activityIndicator.stopAnimating()
            SMCoreLib.Alert.show(fromVC: self, withTitle: "Alert!", message: "An error occurred: \(message)")
            
        case .syncStarted:
            activityIndicator.startAnimating()
            
        case .syncServerDown:
            activityIndicator.stopAnimating()
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
    
        // Can't seem to do this with `performBatchUpdates` to get animations. It crashes.
        collectionView.reloadData()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Put these here because the ImagesVC changes them.
        setupHandlers()
        
        // Putting this in `viewWillAppear` to deal with the first time the Albums are displayed and to deal with removal of an album in ImagesVC. And to deal with sharing group updates from other places in the app.
        updateSharingGroups()
        
        if shouldLayoutSubviews {
            shouldLayoutSubviews = false
            layoutSubviews()
        }
        
        Progress.session.viewController = self
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        if SharingInviteDelegate.invitationRedeemed {
            SharingInviteDelegate.invitationRedeemed = false
            
            activityIndicator.startAnimating()
            do {
                try SyncServer.session.sync()
            } catch (let error) {
                SMCoreLib.Alert.show(fromVC: self, withTitle: "Could not sync", message: "\(error)")
            }
        }
        
        Notifications.checkForNotificationAuthorization(usingViewController: self)
    }
    
    private func layoutSubviews() {
    }
    
    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        
        // To resize cells when we rotate the device.
        // 9/10/18; Got a crash here on accepting an invitation because self.collectionView was nil.
        if let flowLayout = self.collectionView?.collectionViewLayout as? UICollectionViewFlowLayout {
                flowLayout.invalidateLayout()
        }
    }
    
    private func saveNewSharingGroupName(sharingGroupUUID: String, newName: String) {
        do {
            try SyncServer.session.updateSharingGroup(sharingGroupUUID: sharingGroupUUID, newSharingGroupName: newName)
            try SyncServer.session.sync(sharingGroupUUID: sharingGroupUUID)
        } catch (let error) {
            Log.msg("\(error)")
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

        albumCell.setup(sharingGroup: sharingGroup, enableGroupNameEditing: sharingGroup.permission.hasMinimumPermission(.write))
        albumCell.tapAction = { [unowned self] in
            self.gotoAlbum(sharingGroup: sharingGroup)
        }
        albumCell.albumSyncAction = { [unowned self] in
            self.gotoAlbum(sharingGroup: sharingGroup, initialSync: true)
        }
        albumCell.saveAction = { newName in
            self.saveNewSharingGroupName(sharingGroupUUID: sharingGroup.sharingGroupUUID, newName: newName)
        }
        albumCell.startEditing = {
            self.addAlbum.isEnabled = false
        }
        albumCell.endEditing = {
            self.addAlbum.isEnabled = true
        }
        
        return cell
    }
    
    private func gotoAlbum(sharingGroup: SyncServer.SharingGroup, initialSync: Bool=false) {
        let vc = ImagesVC.create()
        vc.sharingGroup = sharingGroup
        vc.imagesHandler = self.imagesHandler
        vc.initialSync = initialSync
        self.navigationController?.pushViewController(vc, animated: true)
    }
}

extension AlbumsVC: UICollectionViewDelegateFlowLayout {
    // From https://stackoverflow.com/questions/14674986/uicollectionview-set-number-of-columns
    func collectionView(_ collectionView: UICollectionView,
        layout collectionViewLayout: UICollectionViewLayout,
        sizeForItemAt indexPath: IndexPath) -> CGSize {
        
        let flowLayout = collectionViewLayout as! UICollectionViewFlowLayout
        let totalSpace = flowLayout.sectionInset.left
                + flowLayout.sectionInset.right
                + (flowLayout.minimumInteritemSpacing * CGFloat(numberOfItemsPerRow - 1))
        let size = (collectionView.bounds.width - totalSpace) / CGFloat(numberOfItemsPerRow)
        
        return CGSize(width: size, height: size)
    }
}
