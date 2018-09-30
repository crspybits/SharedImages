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

class AlbumsVC: UIViewController {
    @IBOutlet weak var collectionView: UICollectionView!
    let reuseIdentifier = "CollectionViewCell"
    let numberOfItemsPerRow = 2
    private var sharingGroups:[SyncServer.SharingGroup]!

    // Sets up delegate for SyncServer also.
    private var imagesHandler = ImagesHandler()
    private var shouldLayoutSubviews = true
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    private var addAlbum:UIBarButtonItem!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        collectionView.dataSource = self
        collectionView.delegate = self
        let layout = UICollectionViewFlowLayout()
        layout.sectionInset = UIEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)
        collectionView.collectionViewLayout = layout
        collectionView.register(UICollectionViewCell.self, forCellWithReuseIdentifier: reuseIdentifier)
        
        sharingGroups = SyncServer.session.sharingGroups
        sortSharingGroups()
        imagesHandler.syncEventAction = syncEvent
        
        addAlbum = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(addAlbumAction))
        navigationItem.rightBarButtonItem = addAlbum
    }
    
    private func sortSharingGroups() {
        sharingGroups.sort { sg1, sg2 in
            if let name1 = sg1.sharingGroupName, let name2 = sg2.sharingGroupName {
                return name1 < name2
            }
            return true
        }
    }
    
    @objc private func addAlbumAction() {
        let newSharingGroupUUID = UUID().uuidString
        do {
            try SyncServer.session.createSharingGroup(sharingGroupUUID: newSharingGroupUUID)
            try SyncServer.session.sync(sharingGroupUUID: newSharingGroupUUID)
        } catch (let error) {
            Log.msg("\(error)")
            SMCoreLib.Alert.show(fromVC: self, withTitle: "Alert!", message: "Could not add album. Please try again later.")
        }
    }
    
    private func syncEvent(event: SyncControllerEvent) {
        switch event {
        case .syncDelayed:
            activityIndicator.stopAnimating()
        case .syncDone(numberOperations: _):
            activityIndicator.stopAnimating()
            sharingGroups = SyncServer.session.sharingGroups
            sortSharingGroups()
            
            // Can't seem to do this with `performBatchUpdates` to get animations. It crashes.
            collectionView.reloadData()
        case .syncError(message: _):
            activityIndicator.stopAnimating()
        case .syncStarted:
            activityIndicator.startAnimating()
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        if shouldLayoutSubviews {
            shouldLayoutSubviews = false
            layoutSubviews()
        }
    }
    
    private func layoutSubviews() {
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
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
        }

        albumCell.setup(sharingGroup: sharingGroup)
        albumCell.tapAction = {
            Log.msg("Tap!")
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
