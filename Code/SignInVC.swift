//
//  SignInVC.swift
//  SharedImages
//
//  Created by Christopher Prince on 3/12/17.
//  Copyright © 2017 Spastic Muffin, LLC. All rights reserved.
//

import Foundation
import UIKit
import SMCoreLib
import SyncServer
import SyncServer_Shared

// This view controller doesn't load upon initial launch of the app, if the user is signed in (silent sign in), and the AppDelegate takes the user directly to the ImagesVC.

class SignInVC : UIViewController, GoogleSignInUIProtocol {
    @IBOutlet weak var signInContainer: UIView!
    
    // static private var rawSharingPermission:SMPersistItemString = SMPersistItemString(name: "SignInVC.rawSharingPermission", initialStringValue: "", persistType: .userDefaults)
    
    var googleSignInButton: TappableButton!
    var facebookSignInButton: TappableButton!
    var dropboxSignInButton:TappableButton!
    var signIn:SignIn!
    
    private var acceptSharingInvitation: Bool = false
    private var invite:SharingInvitation.Invitation?
    
    var sharingDelegate:SharingInviteDelegate!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // TODO: *2* Signing out and then signing in as a different user will mess up this app. What we're really assuming is that the user may sign out, but will then again sign in as the same user. If the user signs in as a different user, we need to alert them that this is going to remove all local files. And, signing in again as the prior user will cause redownload of the prior files. This may be something we want to fix in the future: To enable the client to handle multiple users. This would require indexing the meta data by user.
        
        // NOTE: When adding a new sign-in-- you need to add it here, and in SetupSignIn.swift.

        googleSignInButton = SetupSignIn.session.googleSignIn.setupSignInButton(params: ["delegate": self])
        SetupSignIn.session.googleSignIn.delegate = self
        
        facebookSignInButton = SetupSignIn.session.facebookSignIn.setupSignInButton(params:nil)
        facebookSignInButton.frameWidth = googleSignInButton.frameWidth
        SetupSignIn.session.facebookSignIn.delegate = self
        
        dropboxSignInButton = SetupSignIn.session.dropboxSignIn.setupSignInButton(params: ["viewController": self])
        dropboxSignInButton.frameSize = CGSize(width: googleSignInButton.frameWidth, height: googleSignInButton.frameHeight * 0.75)
        SetupSignIn.session.dropboxSignIn.delegate = self
        
        signIn = SignIn.createFromXib()!
        signInContainer.addSubview(signIn)
        
        sharingDelegate = SharingInviteDelegate(withNotSignedInCallback: {[unowned self] invite in
            self.acceptSharingInvitation = true
            self.invite = invite
            self.signIn.showSignIns(for: .sharingAccount)
        })
        
        SharingInvitation.session.delegate = sharingDelegate
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        // 12/29/17; Because of https://github.com/crspybits/SharedImages/issues/42
        if let invite = SharingInvitation.session.receive() {
            self.invite = invite
            sharingDelegate.sharingInvitationReceived(invite)
        }
    }
}

extension SignInVC : GenericSignInDelegate {
    func shouldDoUserAction(signIn:GenericSignIn) -> UserActionNeeded {
        var result:UserActionNeeded = .error
        
        if SignInManager.currentUserId.stringValue != "" &&
            signIn.credentials?.userId != nil &&
            SignInManager.currentUserId.stringValue != signIn.credentials?.userId &&
            Image.fetchAll().count > 0 {
            
            // Attempting to sign in as a different user, and there are images present. Yikes.  Not allowing this yet because this would try to access a different account on the server and would just confuse things.
            signIn.signUserOut()
            Log.msg("signUserOut: SignInVc: shouldDoUserAction")
            
            var title:String = "You are trying to sign in as a different user than before."
            if SignInManager.currentUIDisplayName.stringValue != "" {
                title = "You were previously signed in as \(SignInManager.currentUIDisplayName.stringValue) but you are now signing in as a different user."
            }
            
            let alert = UIAlertController(title: title, message: "The Shared Images app doesn't allow this (yet).", preferredStyle: .actionSheet)
            alert.popoverPresentationController?.sourceView = navigationController?.navigationBar
            Alert.styleForIPad(alert)

            alert.addAction(UIAlertAction(title: "OK", style: .cancel) {alert in
            })
            self.present(alert, animated: true, completion: nil)
        }
        else if invite != nil && acceptSharingInvitation {
            acceptSharingInvitation = false
            result = .createSharingUser(invitationCode: invite!.sharingInvitationCode)
        }
        else {
            switch SignIn.userInterfaceState {
            case .createNewAccount:
                result = .createOwningUser
            
            case .existingAccount:
                result = .signInExistingUser
                
            case .initialSignInViewShowing:
                Log.error("initialSignInViewShowing")
            }
        }
        
        return result
    }
    
    func userActionOccurred(action:UserActionOccurred, signIn:GenericSignIn) {
        func successfulSignIn(switchToImagesTab:Bool = false) {
            if SignInManager.currentUserId.stringValue == "" {
                // No user signed in yet.
                SignInManager.currentUIDisplayName.stringValue = signIn.credentials?.uiDisplayName ?? ""
                SignInManager.currentUserId.stringValue = signIn.credentials?.userId ?? ""
            }

            if switchToImagesTab {
                if SignInManager.session.lastStateChangeSignedUserIn {
                    (UIApplication.shared.delegate as! AppDelegate).selectTabInController(tab: .images)
                }
            }
        }
        
        switch action {
        case .userSignedOut:
            // Don't need to switch the tab to the SignInVC-- that's already done.
            break
            
        case .userNotFoundOnSignInAttempt:
            SMCoreLib.Alert.show(withTitle: "Alert!", message: "User not found on system.")
            // Don't need to sign the user out-- already signed out when delegate called.
            
        case .existingUserSignedIn:
            successfulSignIn(switchToImagesTab: true)
            
        case .owningUserCreated:
            // 12/26/17;  https://github.com/crspybits/SharedImages/issues/54
            successfulSignIn(switchToImagesTab: true)
            
        case .sharingUserCreated:
            invite = nil
            SharingInviteDelegate.invitationRedeemed = true
            
            // 12/26/17; https://github.com/crspybits/SharedImages/issues/54
            successfulSignIn(switchToImagesTab: true)
        }
    }
}

extension UIView {
    // Calling this multiple times creates multiple sets of constraints.
    func setAnchorsFromSize() {
        heightAnchor.constraint(equalToConstant: frame.size.height).isActive = true
        widthAnchor.constraint(equalToConstant: frame.size.width).isActive = true
    }

    static func createFromXib<T>() -> T? {
        let bundle = Bundle(for: SignInManager.self)
        guard let viewType = bundle.loadNibNamed(typeName(self), owner: self, options: nil)?[0] as? T else {
            assert(false)
            return nil
        }
        
        return viewType
    }
}
