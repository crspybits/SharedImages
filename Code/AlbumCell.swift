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
    @IBOutlet weak var image: UIImageView!
    private let badge = BadgeSwift()
    @IBOutlet weak var albumName: UITextField!
    private var sharingGroup: SyncServer.SharingGroup!
    
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
    
    func setup(sharingGroup: SyncServer.SharingGroup) {
        self.sharingGroup = sharingGroup
        setAlbumName()
        
        self.image.image = nil
        badge.removeFromSuperview()
        DispatchQueue.main.async {
            if let images = Image.fetchObjectsWithSharingGroupUUID(sharingGroup.sharingGroupUUID), images.count > 0 {
                self.getImageForCell(images: images)
                self.setUnreadCount(images: images)
            }
        }
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
            badge.format(withUnreadCount: unreadCount)
            image.addSubview(badge)
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
}
