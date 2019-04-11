//
//  AlbumSharingVC.swift
//  SharedImages
//
//  Created by Christopher G Prince on 4/7/19.
//  Copyright © 2019 Spastic Muffin, LLC. All rights reserved.
//

import UIKit
import SMCoreLib
import SyncServer
import SyncServer_Shared
import NVActivityIndicatorView

class AlbumSharingVC: UIViewController, NVActivityIndicatorViewable {
    @IBOutlet weak var sharingCode: UITextField!
    @IBOutlet weak var acceptSharingInvitation: UIButton!
    
    static func create() -> AlbumSharingVC {
        return UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "AlbumSharingVC") as! AlbumSharingVC
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.title = "Album Sharing"
        acceptSharingInvitation.isEnabled = false
    }
    
    private func startActivityIndicator() {
        let minDisplayTimeMilliseconds = 300
        let size = CGSize(width: 50, height: 50)
        let indicatorType:NVActivityIndicatorType = .lineSpinFadeLoader
        startAnimating(size, message: "Checking...", type: indicatorType, minimumDisplayTime: minDisplayTimeMilliseconds, fadeInAnimation: nil)
    }
    
    private func stopActivityIndicator() {
        stopAnimating(nil)
    }
    
    @IBAction func acceptSharingInvitationAction(_ sender: Any) {
        guard let code = sharingCode.text else {
            return
        }
        
        // So keyboard isn't up when we do the get sharing info server call & we can show an activity indicator.
        sharingCode.resignFirstResponder()
        
        startActivityIndicator()
        
        // This call doesn't require the user to be signed in.
        SyncServerUser.session.getSharingInvitationInfo(invitationCode: code) { info, error in
            self.stopActivityIndicator()
            
            guard let info = info, error == nil else {
                SMCoreLib.Alert.show(withTitle: "Alert!", message: "Could not get information on this sharing invitation.")
                return
            }
            
            switch info {
            case .noInvitationFound:
                SMCoreLib.Alert.show(withTitle: "Alert!", message: "Could not find sharing invitation on server. Has it expired?")
            case .invitation(let invite):
                self.redeem(invitation: invite)
            }
        }
    }
    
    func redeem(invitation: SyncServer.Invitation) {
        let isSocial = SignInManager.session.currentSignIn?.userType == .sharing
        if !invitation.allowsSocialSharing && isSocial {
            SMCoreLib.Alert.show(withTitle: "Alert!", message: "You are signed in as a sharing user (e.g., Facebook), but the invitation only allows owning users (e.g., Dropbox or Google). Sorry!")
            return
        }
        
        SharingInviteDelegate.redeem(invitationCode: invitation.code, success:{
            SMCoreLib.Alert.show(withTitle: "Success!", message: "You have now joined the new album!")
        },
        failure: { failure in
            switch failure {
            case .error, .noCredentials:
                SMCoreLib.Alert.show(withTitle: "Alert!", message: "Failed joining the new album.")
            case .userNotSignedIn:
                SMCoreLib.Alert.show(withTitle: "You will need to sign in as a new user to redeem the invitation.", allowCancel: true, okCompletion:{
                    let signIn = SignInVC.create()
                    signIn.userNotSignedIn(invitation: invitation)
                    SideMenu.session.setRootViewController(signIn, animation: true)
                })
            }
        })
    }
    
    // See https://stackoverflow.com/questions/44227910/replace-character-while-user-is-typing
    @IBAction func sharingCodeChangedAction(_ sender: Any) {
        if let text = sharingCode.text, let _ = UUID(uuidString: text) {
            acceptSharingInvitation.isEnabled = true
        }
        else {
            acceptSharingInvitation.isEnabled = false
        }
    }
}
