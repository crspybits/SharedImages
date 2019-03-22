//
//  AlbumCell.swift
//  SharedImages
//
//  Created by Christopher G Prince on 9/29/18.
//  Copyright © 2018 Spastic Muffin, LLC. All rights reserved.
//

import UIKit
import SyncServer
import SMCoreLib
import BadgeSwift

class AlbumCell: UIView, XibBasics {
    typealias ViewType = AlbumCell
    var tapAction:(()->())?
    var saveAction:((_ newSharingGroupName: String)->())?
    var startEditing:(()->())?
    var endEditing:(()->())?
    var albumSyncAction:(()->())?
    @IBOutlet weak var image: UIImageView!
    private let unreadCountBadge = BadgeSwift()
    @IBOutlet weak var albumName: UITextField!
    private var sharingGroup: SyncServer.SharingGroup!
    @IBOutlet weak var albumSyncNeeded: UIView!
    @IBOutlet weak var shareImage: UIImageView!
    private var sharingOn: Bool = false

    override func awakeFromNib() {
        super.awakeFromNib()
        albumName.delegate = self
        albumName.inputAccessoryView = AlbumCell.makeToolBar(doneAction: Action(target: self, selector: #selector(save)), cancelAction: Action(target: self, selector: #selector(cancel)))
    }
    
    private func setAlbumName() {
        if let sharingGroupName = sharingGroup.sharingGroupName {
            albumName.text = sharingGroupName
        }
        else {
            albumName.text = "Album"
        }
    }
    
    func setup(sharingGroup: SyncServer.SharingGroup, enableGroupNameEditing: Bool, sharingOn: Bool) {
        self.sharingGroup = sharingGroup
        self.sharingOn = sharingOn
        
        setAlbumName()
        
        albumName.isEnabled = enableGroupNameEditing
        
        self.image.image = nil
        unreadCountBadge.removeFromSuperview()
        
        if let images = Image.fetchObjectsWithSharingGroupUUID(sharingGroup.sharingGroupUUID), images.count > 0 {
            self.getImageForCell(images: images)
            self.setUnreadCount(images: images)
        }
        
        setSyncNeeded()
        
        UIView.animate(withDuration: 0.2) {[unowned self] in
            if sharingOn {
                self.image.alpha = 0.75
                self.shareImage.alpha = 1
            }
            else {
                self.image.alpha = 1.0
                self.shareImage.alpha = 0
            }
        }
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
    
    private func getImageForCell(images: [Image]) {
        if let imageURL = images[0].url {
            var image: UIImage!
            do {
                let imageData = try Data(contentsOf: imageURL as URL)
                image = UIImage(data: imageData)
            } catch {
                print("Error loading image : \(error)")
                return
            }
            
            self.image.image = image
        }
    }
    
    private func setUnreadCount(images: [Image]) {
        var unreadCount = 0
        images.forEach { image in
            if let discussion = image.discussion {
                unreadCount += Int(discussion.unreadCount)
            }
        }
        
        if unreadCount > 0 {
            unreadCountBadge.format(withUnreadCount: unreadCount)
            image.addSubview(unreadCountBadge)
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

extension AlbumCell: UITextFieldDelegate {
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
