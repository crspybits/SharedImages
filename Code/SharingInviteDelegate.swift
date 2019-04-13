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
    private var withNotSignedInCallback: ((SyncServer.Invitation)->())?
    static var invitationRedeemed = false
    
    init(withNotSignedInCallback: ((SyncServer.Invitation)->())? = nil) {
        self.withNotSignedInCallback = withNotSignedInCallback
    }
    
    func sharingInvitationReceived(_ invite:SyncServer.Invitation) {
        guard let vc = UIViewController.getTop() else {
            return
        }
        
#if false
        SMCoreLib.Alert.show(withTitle: "SharingInvitation", message: "code: \(invite.sharingInvitationCode)")
#endif

        // Creating a user.
        let userFriendlyText = invite.permission.userFriendlyText()
        let alert = UIAlertController(title: "Do you want to share the images (\(userFriendlyText)) in the invitation?", message: nil, preferredStyle: Alert.prominentStyle())
        Alert.styleForIPad(alert)
        alert.popoverPresentationController?.sourceView = vc.view

        alert.addAction(UIAlertAction(title: "Not now", style: .cancel) {alert in
        })
        alert.addAction(UIAlertAction(title: "Share", style: .default) {[unowned self] alert in
            SharingInviteDelegate.redeem(invitationCode: invite.code, success: {
                SharingInviteDelegate.invitationRedeemed = true
            }, failure: { failure in
                switch failure {
                case .error, .noCredentials:
                    break
                case .userNotSignedIn:
                    self.withNotSignedInCallback?(invite)
                }
            })
        })
        
        vc.present(alert, animated: true, completion: nil)
    }
    
    enum Failure {
        // These two cases show an alert before returning.
        case error(Error)
        case noCredentials

        // No alert is shown before returning.
        case userNotSignedIn
    }
    
    static func redeem(invitationCode: String, success:(()->())? = nil, failure:((Failure)->())? = nil) {
        if SignInManager.session.userIsSignedIn {
            if let credentials = SignInManager.session.currentSignIn?.credentials {
                SyncServerUser.session.redeemSharingInvitation(creds: credentials, invitationCode: invitationCode, cloudFolderName: SyncServerUser.session.cloudFolderName) { longLivedAccessToken, sharingGroupUUID, error in
                    if error == nil {
                        SharingInviteDelegate.invitationRedeemed = true
                        SMCoreLib.Alert.show(withTitle: "Success!", message: "You now have a new shared album!")
                        success?()
                    }
                    else if case .socialAcceptanceNotAllowed = error! {
                        Log.error("Error: \(error!)")
                        SMCoreLib.Alert.show(withTitle: "Alert!", message: "Unfortunately, you are signed in with a social account (e.g., Facebook), but the invitation requires acceptance with an owning account (e.g., Dropbox, Google).")
                        failure?(.error(error!))
                    }
                    else {
                        Log.error("Error: \(error!)")
                        SMCoreLib.Alert.show(withTitle: "Alert!", message: "Error accepting sharing invitation!")
                        failure?(.error(error!))
                    }
                }
            }
            else {
                SMCoreLib.Alert.show(withTitle: "Alert!", message: "User is signed in, but there are no credentials!")
                failure?(.noCredentials)
            }
        }
        else {
            failure?(.userNotSignedIn)
        }
    }
}
