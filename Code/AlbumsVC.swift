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
    
    override func viewDidLoad() {
        super.viewDidLoad()
        collectionView.dataSource = self
        collectionView.delegate = self
        let layout = UICollectionViewFlowLayout()
        layout.sectionInset = UIEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)
        collectionView.collectionViewLayout = layout
        collectionView.register(UICollectionViewCell.self, forCellWithReuseIdentifier: reuseIdentifier)
        
        sharingGroups = SyncServer.session.sharingGroups
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
