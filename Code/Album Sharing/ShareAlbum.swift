//
//  ShareAlbum.swift
//  SharedImages
//
//  Created by Christopher G Prince on 3/21/19.
//  Copyright © 2019 Spastic Muffin, LLC. All rights reserved.
//

import Foundation
import SyncServer_Shared
import SyncServer
import SMCoreLib
import NVActivityIndicatorView

class ShareAlbum {
    private let sharingGroup: SyncServer.SharingGroup
    private weak var viewController: (UIViewController & NVActivityIndicatorViewable)!
    private let view: UIView
    private let sharingButton: UIBarButtonItem
    
    init(sharingGroup: SyncServer.SharingGroup, fromView view: UIView, viewController: UIViewController & NVActivityIndicatorViewable, sharingButton: UIBarButtonItem) {
        self.sharingGroup = sharingGroup
        self.viewController = viewController
        self.view = view
        self.sharingButton = sharingButton
    }
    
    func start() {
        if SignInManager.session.userIsSignedIn {
            ShareAlbumVC.show(fromParentVC: viewController, sharingGroup: sharingGroup, cancel: {
            }, invite: { parameters in
                self.completeSharing(params: parameters)
            })
        }
        else {
            let alert = UIAlertController(title: "Please sign in first!", message: "There is no signed in user.", preferredStyle: .actionSheet)
            alert.addAction(UIAlertAction(title: "OK", style: .default){alert in
            })
            
            Alert.styleForIPad(alert)
            alert.popoverPresentationController?.barButtonItem = self.sharingButton
            viewController.present(alert, animated: true, completion: nil)
        }
    }
    
    private func completeSharing(params:ShareAlbumVC.InvitationParameters) {
        let size = CGSize(width: 50, height: 50)
        let indicatorType:NVActivityIndicatorType = .lineSpinFadeLoader
        viewController.startAnimating(size, message: "Creating...", type: indicatorType, fadeInAnimation: nil)
        
        SyncServerUser.session.createSharingInvitation(withPermission: params.permission, sharingGroupUUID: sharingGroup.sharingGroupUUID, numberAcceptors: params.numberAcceptors, allowSharingAcceptance: params.allowSocialAcceptance) {[unowned self] invitationCode, error in
            self.viewController.stopAnimating(nil)
            if error == nil {
                var socialText = " "
                if params.allowSocialAcceptance {
                    socialText = ", Facebook, "
                }
                
                var albumName = "an album of images"
                var subjectAlbumName = ""
                if let name = self.sharingGroup.sharingGroupName {
                    albumName = "the album of images '\(name)'"
                    subjectAlbumName = "\(name) "
                }
                
                let sharingURLString = SharingInvitation.createSharingURL(invitationCode: invitationCode!)
                if let email = SMEmail(parentViewController: self.viewController) {
                    let message = "I'd like to share \(albumName) with you through the Neebla app and your Dropbox\(socialText)or Google account. To share images, you need to:\n" +
                        "1) download the Neebla iOS app onto your iPhone or iPad,\n" +
                        "2) tap the link below in the Apple Mail app, and\n" +
                        "3) follow the instructions within the app to sign in to your Dropbox\(socialText)or Google account.\n" +
                        "You will have " + params.permission.userFriendlyText() + " access to images.\n\n" +
                            sharingURLString +
                        "\n\n" +
                        "If you can't tap the link above, then you can copy the code below:\n" +
                        "\t\(invitationCode!)\n" +
                        "and paste it into the 'Album Sharing' screen of the Neebla app"
                    
                    email.setMessageBody(message, isHTML: false)
                    email.setSubject("Share \(subjectAlbumName)images using the Neebla app")
                    email.show()
                }
            }
            else {
                let alert = UIAlertController(title: "Error creating sharing invitation!", message: "\(error!)", preferredStyle: .alert)
                alert.popoverPresentationController?.sourceView = self.view
                Alert.styleForIPad(alert)

                alert.addAction(UIAlertAction(title: "OK", style: .cancel) {alert in
                })
                self.viewController.present(alert, animated: true, completion: nil)
            }
        }
    }
}
