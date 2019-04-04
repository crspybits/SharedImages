//
//  ShareAlbumPermissionCell.swift
//  SharedImages
//
//  Created by Christopher G Prince on 4/3/19.
//  Copyright © 2019 Spastic Muffin, LLC. All rights reserved.
//

import UIKit
import SyncServer_Shared

class ShareAlbumPermissionCell: UITableViewCell {
    @IBOutlet weak var readOnly: UIButton!
    @IBOutlet weak var readAndWrite: UIButton!
    @IBOutlet weak var readWriteAndInvite: UIButton!
    
    private(set) var permission:Permission = .write
    
    override func awakeFromNib() {
        super.awakeFromNib()
    }
    
    private func updateStates(oldPermission: Permission) {
        if oldPermission == permission {
            return
        }
        
        let buttons:[Permission: UIButton] = [.read: readOnly, .write: readAndWrite, .admin: readWriteAndInvite]
        
        UIView.animate(withDuration: 0.3) {[unowned self] in
            if let oldButton = buttons[oldPermission] {
                oldButton.alpha = 0.5
            }
            if let newButton = buttons[self.permission] {
                newButton.alpha = 1
            }
        }
    }
    
    @IBAction func readOnlyAction(_ sender: Any) {
        let oldPermission = permission
        permission = .read
        updateStates(oldPermission: oldPermission)
    }
    
    @IBAction func readAndWriteAction(_ sender: Any) {
        let oldPermission = permission
        permission = .write
        updateStates(oldPermission: oldPermission)
    }
    
    @IBAction func readWriteAndInviteAction(_ sender: Any) {
        let oldPermission = permission
        permission = .admin
        updateStates(oldPermission: oldPermission)
    }
}
