//
//  SharingInviteDelegate.swift
//  SharedImages
//
//  Created by Christopher G Prince on 10/10/18.
//  Copyright © 2018 Spastic Muffin, LLC. All rights reserved.
//

import Foundation
import SyncServer
import SMCoreLib

class SharingInviteDelegate : SharingInvitationDelegate {
    private var withNotSignedInCallback: ((SharingInvitation.Invitation)->())?
        
    init(withNotSignedInCallback: ((SharingInvitation.Invitation)->())? = nil) {
        self.withNotSignedInCallback = withNotSignedInCallback
    }
    
    func sharingInvitationReceived(_ invite:SharingInvitation.Invitation) {
        guard let vc = UIViewController.getTop() else {
            return
        }
        
#if false
        SMCoreLib.Alert.show(withTitle: "SharingInvitation", message: "code: \(invite.sharingInvitationCode)")
#endif

        // Creating a user.
        let userFriendlyText = invite.sharingInvitationPermission.userFriendlyText()
        let alert = UIAlertController(title: "Do you want to share the images (\(userFriendlyText)) in the invitation?", message: nil, preferredStyle: .actionSheet)
        Alert.styleForIPad(alert)
        alert.popoverPresentationController?.sourceView = vc.view

        alert.addAction(UIAlertAction(title: "Not now", style: .cancel) {alert in
        })
        alert.addAction(UIAlertAction(title: "Share", style: .default) {[unowned self] alert in
            if SignInManager.session.userIsSignedIn {
                if let credentials = SignInManager.session.currentSignIn?.credentials {
                    SyncServerUser.session.redeemSharingInvitation(creds: credentials, invitationCode: invite.sharingInvitationCode, cloudFolderName: SyncServerUser.session.cloudFolderName) { longLivedAccessToken, sharingGroupUUID, error in
                        if error == nil {
                            SMCoreLib.Alert.show(withTitle: "Success!", message: "You now have a new shared album: Pull-down to refresh to see it!")
                        }
                        else {
                            Log.error("Error: \(error!)")
                            SMCoreLib.Alert.show(withTitle: "Alert!", message: "Error accepting sharing invitation!")
                        }
                    }
                }
                else {
                    SMCoreLib.Alert.show(withTitle: "Alert!", message: "User is signed in, but there are no credentials!")
                }
            }
            else {
                self.withNotSignedInCallback?(invite)
            }
        })
        
        vc.present(alert, animated: true, completion: nil)
    }
}
