//
//  AlbumCollectionViewCell.swift
//  SharedImages
//
//  Created by Christopher G Prince on 5/14/19.
//  Copyright © 2019 Spastic Muffin, LLC. All rights reserved.
//

import UIKit
import SyncServer
import SMCoreLib
import BadgeSwift

class AlbumCollectionViewCell: UICollectionViewCell {
    var tapAction:(()->())?
    var saveAction:((_ newSharingGroupName: String)->())?
    var startEditing:(()->())?
    var endEditing:(()->())?
    var albumSyncAction:(()->())?
    @IBOutlet weak var mediaViewContainer: MediaViewContainer!
    private let unreadCountBadge = BadgeSwift()
    @IBOutlet weak var albumName: UITextField!
    private var sharingGroup: SyncServer.SharingGroup!
    @IBOutlet weak var albumSyncNeeded: UIView!
    @IBOutlet weak var shareImage: UIImageView!
    private var sharingOn: Bool = false
    private var sharingReallyOn: Bool = false

    override func awakeFromNib() {
        super.awakeFromNib()
        albumName.delegate = self
        albumName.inputAccessoryView = AlbumCollectionViewCell.makeToolBar(doneAction: Action(target: self, selector: #selector(save)), cancelAction: Action(target: self, selector: #selector(cancel)))
    }
    
    private func setAlbumName() {
        if let sharingGroupName = sharingGroup.sharingGroupName {
            albumName.text = sharingGroupName
        }
        else {
            albumName.text = "Album"
        }
    }
    
    private let urlBackgroundColor = UIColor(white: 0.9, alpha: 1)
    
    func setup(sharingGroup: SyncServer.SharingGroup, cache: LRUCache<ImageMediaObject>, enableGroupNameEditing: Bool, sharingOn: Bool, sharingReallyOn:Bool) {
        self.sharingGroup = sharingGroup
        self.sharingOn = sharingOn
        self.sharingReallyOn = sharingReallyOn
        
        // The reason for this background color is to have a solid background color when URL preview's change to non-icon's-- they look odd otherwise.
        backgroundColor = urlBackgroundColor

        setAlbumName()
        
        albumName.isEnabled = enableGroupNameEditing
        unreadCountBadge.removeFromSuperview()
        
        if let media = FileMediaObject.fetchObjectsWithSharingGroupUUID(sharingGroup.sharingGroupUUID), media.count > 0,
            let mediaObject = media.first! as? MediaType {
            mediaViewContainer.setup(with: mediaObject, cache: cache, backgroundColor: urlBackgroundColor, albumsView: true)

            if let mediaOriginalSize = mediaObject.originalSize  {
                let smallerSize = ImageExtras.boundingImageSizeFor(originalSize: mediaOriginalSize, boundingSize: frameSize)
                mediaViewContainer.mediaView?.showWith(size: smallerSize)
            }
            
            self.setUnreadCount(media: media)
        }
        else {
            mediaViewContainer.mediaView = nil
            mediaViewContainer.backgroundColor = urlBackgroundColor
        }
        
        setSyncNeeded()
        
        UIView.animate(withDuration: 0.2) {[unowned self] in
            if sharingReallyOn {
                self.mediaViewContainer.alpha = 0.75
                self.shareImage.alpha = 0.5
            }
            else {
                self.mediaViewContainer.alpha = 1.0
                self.shareImage.alpha = 0
            }
        }
    }
    
    func flashSharingIcon(completion: @escaping ()->()) {
        UIView.animate(withDuration: 0.3, animations: {
            self.shareImage.alpha = 1
        }, completion: {_ in
            completion()
        })
    }
    
    private func setSyncNeeded() {
        let sharingGroups = SyncServer.session.sharingGroups
        let filtered = sharingGroups.filter {$0.sharingGroupUUID == self.sharingGroup.sharingGroupUUID}
        guard filtered.count == 1 else {
            return
        }
        
        let sharingGroup = filtered[0]
        albumSyncNeeded.isHidden = !sharingGroup.syncNeeded!
    }
    
    private func setUnreadCount(media: [FileMediaObject]) {
        var unreadCount = 0
        media.forEach { mediaObj in
            if let discussion = mediaObj.discussion {
                unreadCount += Int(discussion.unreadCount)
            }
        }
        
        if unreadCount > 0 {
            unreadCountBadge.format(withUnreadCount: unreadCount)
            mediaViewContainer.addSubview(unreadCountBadge)
        }
    }
    
    @IBAction func tapAction(_ sender: Any) {
        tapAction?()
    }
    
    @objc private func save() {
        albumName.resignFirstResponder()
        
        var newName = ""
        if let name = albumName.text {
            newName = name
        }
        
        saveAction?(newName)
    }

    @objc private func cancel() {
        albumName.resignFirstResponder()
        setAlbumName()
    }
    
    @IBAction func albumSyncAction(_ sender: Any) {
        albumSyncAction?()
    }
    
    struct Action {
        let target: Any
        let selector: Selector
    }
    
    static func makeToolBar(doneAction:Action, cancelAction:Action) -> UIToolbar {
        let screenWidth = UIScreen.main.bounds.width
        let toolbar:UIToolbar = UIToolbar(frame: CGRect(x: 0, y: 0,  width: screenWidth, height: 30))
        
        let cancelButton = UIBarButtonItem(title: "Cancel", style: .plain, target: cancelAction.target, action: cancelAction.selector)
        let flexSpace = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        let doneButton = UIBarButtonItem(title: "Save", style: .done, target: doneAction.target, action: doneAction.selector)
        
        let buttonItems = [cancelButton, flexSpace, doneButton]
        
        toolbar.setItems(buttonItems, animated: false)
        toolbar.sizeToFit()
       
        return toolbar
    }
}

extension AlbumCollectionViewCell: UITextFieldDelegate {
    public func textFieldShouldBeginEditing(_ textField: UITextField) -> Bool {
        if sharingOn {
            // So user can't edit name while in sharing mode. Which is a little strange.
            return false
        }
        
        startEditing?()
        albumName.borderStyle = .roundedRect
        albumName.backgroundColor = .white
        return true
    }
    
    func textFieldDidEndEditing(_ textField: UITextField) {
        textField.text = textField.text?.trimmingCharacters(in: .whitespacesAndNewlines)
        albumName.borderStyle = .none
        albumName.backgroundColor = .clear
        endEditing?()
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.text = textField.text?.trimmingCharacters(in: .whitespacesAndNewlines)
        save()
        return true
    }
}
