//
//  AlbumSharingVC.swift
//  SharedImages
//
//  Created by Christopher G Prince on 4/7/19.
//  Copyright © 2019 Spastic Muffin, LLC. All rights reserved.
//

import UIKit
import SMCoreLib

class AlbumSharingVC: UIViewController {
    @IBOutlet weak var sharingCode: UITextField!
    @IBOutlet weak var acceptSharingInvitation: UIButton!
    
    static func create() -> AlbumSharingVC {
        return UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "AlbumSharingVC") as! AlbumSharingVC
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.title = "Album Sharing"
        acceptSharingInvitation.isEnabled = false
        sharingCode.delegate = self
    }
    
    @IBAction func acceptSharingInvitationAction(_ sender: Any) {
        guard let code = sharingCode.text else {
            return
        }
        
        SharingInviteDelegate.redeem(invitationCode: code, failure: { failure in
            switch failure {
            case .error, .noCredentials:
                break
            case .userNotSignedIn:
                break
            }
        })
    }
}

extension AlbumSharingVC: UITextFieldDelegate {
    public func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
    
        if let text = textField.text, let textRange = Range(range, in: text) {
        let possibleUUID = text.replacingCharacters(in: textRange, with: string)
            textField.text = possibleUUID
            if let _ = UUID(uuidString: possibleUUID) {
                acceptSharingInvitation.isEnabled = true
            }
            else {
                acceptSharingInvitation.isEnabled = false
            }
        }
        
        return true
    }
}
