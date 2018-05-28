//
//  FacebookSignIn.swift
//  SyncServer
//
//  Created by Christopher Prince on 6/11/16.
//  Copyright © 2016 Spastic Muffin, LLC. All rights reserved.
//

// Enables you to sign in as a Facebook user to (a) create a new sharing user (must have an invitation from another SyncServer user), or (b) sign in as an existing sharing user.

// See the .podspec file for this definition.
#if SYNCSERVER_FACEBOOK_SIGNIN

import Foundation
import SMCoreLib
import FacebookCore
import FacebookLogin
import SyncServer_Shared

public class FacebookCredentials : GenericCredentials {
    fileprivate var accessToken:AccessToken!
    fileprivate var userProfile:UserProfile!
    
    public var userId:String {
        return userProfile.userId
    }
    
    public var username:String {
        return userProfile.fullName!
    }
    
    public var uiDisplayName:String {
        return userProfile.fullName!
    }
    
    public var httpRequestHeaders:[String:String] {
        var result = [String:String]()
        result[ServerConstants.XTokenTypeKey] = ServerConstants.AuthTokenType.FacebookToken.rawValue
        result[ServerConstants.HTTPOAuth2AccessTokenKey] = accessToken.authenticationToken
        return result
    }
    
    public func refreshCredentials(completion: @escaping (SyncServerError?) ->()) {
        completion(.noRefreshAvailable)
        // The AccessToken refresh method doesn't work if the access token has expired. So, I think it's not useful here.
    }
}

public class FacebookSyncServerSignIn : GenericSignIn {
    private var stickySignIn = false

    public var signOutDelegate:GenericSignOutDelegate?
    public var delegate:GenericSignInDelegate?
    public var managerDelegate:SignInManagerDelegate!
    private let signInOutButton:FacebookSignInButton!
    
    public init() {
        signInOutButton = FacebookSignInButton()
        signInOutButton.signIn = self
    }
    
    public var signInTypesAllowed:SignInType = .sharingUser
    
    public func appLaunchSetup(userSignedIn: Bool, withLaunchOptions options:[UIApplicationLaunchOptionsKey : Any]?) {
    
        SDKApplicationDelegate.shared.application(UIApplication.shared, didFinishLaunchingWithOptions: options)
        
        if userSignedIn {
            stickySignIn = true
            if let creds = credentials {
                SyncServerUser.session.creds = creds
            }
            autoSignIn()
        }
    }
    
    public func networkChangedState(networkIsOnline: Bool) {
        if stickySignIn && networkIsOnline && credentials == nil {
            Log.msg("FacebookSignIn: Trying autoSignIn...")
            autoSignIn()
        }
    }
    
    private func autoSignIn() {
        AccessToken.refreshCurrentToken() { (accessToken, error) in
            if error == nil {
                Log.msg("FacebookSignIn: Sucessfully refreshed current access token")
                self.completeSignInProcess(autoSignIn: true)
            }
            else {
                // I.e., I'm not going to force a sign-out because this seems like a generic error. E.g., could have been due to no network connection.
                Log.error("FacebookSignIn: Error refreshing access token: \(error!)")
            }
        }
    }
    
    public func application(_ app: UIApplication, open url: URL, options: [UIApplicationOpenURLOptionsKey : Any] = [:]) -> Bool {
        return SDKApplicationDelegate.shared.application(app, open: url, options: options)
    }

    @discardableResult
    public func setupSignInButton(params:[String:Any]? = nil) -> TappableButton? {
        return signInOutButton
    }
    
    public var signInButton: TappableButton? {
        return signInOutButton
    }
    
    public var userIsSignedIn: Bool {
        return stickySignIn
    }

    // Returns non-nil if the user is signed in, and credentials could be refreshed during this app launch.
    public var credentials:GenericCredentials? {
        if stickySignIn && AccessToken.current != nil {
            let creds = FacebookCredentials()
            creds.accessToken = AccessToken.current
            creds.userProfile = UserProfile.current
            return creds
        }
        else {
            return nil
        }
    }

    public func signUserOut() {
        stickySignIn = false
        
        // Seem to have to do this before the `LoginManager().logOut()`, so we still have a valid token.
        reallySignUserOut()
        
        LoginManager().logOut()
        signOutDelegate?.userWasSignedOut(signIn: self)
        delegate?.userActionOccurred(action: .userSignedOut, signIn: self)
        managerDelegate?.signInStateChanged(to: .signedOut, for: self)
    }
    
    // It seems really hard to fully sign a user out of Facebook. The following helps.
    fileprivate func reallySignUserOut() {
        let deletePermission = GraphRequest(graphPath: "me/permissions/", parameters: [:], accessToken: AccessToken.current, httpMethod: .DELETE)
        deletePermission.start { (response, graphRequestResult) in
            switch graphRequestResult {
            case .success(_):
                Log.msg("Success logging out.")
            case .failed(let error):
                Log.error("Error: Failed logging out: \(error)")
            }
        }
    }
    
    fileprivate func completeSignInProcess(autoSignIn:Bool) {
        stickySignIn = true
        // The Facebook signin button (`LoginButton`) automatically changes it's state to show "Sign out" when signed in. So, don't need to do that manually here.
        
        guard let userAction = delegate?.shouldDoUserAction(signIn: self) else {
            // This occurs if we don't have a delegate (e.g., on a silent sign in). But, we need to set up creds-- because this is what gives us credentials for connecting to the SyncServer.
            SyncServerUser.session.creds = credentials
            managerDelegate?.signInStateChanged(to: .signedIn, for: self)
            return
        }
        
        switch userAction {
        case .signInExistingUser:
            SyncServerUser.session.checkForExistingUser(creds: credentials!) {
                (checkForUserResult, error) in
                if error == nil {
                    switch checkForUserResult! {
                    case .noUser:
                        self.delegate?.userActionOccurred(action:
                            .userNotFoundOnSignInAttempt, signIn: self)
                        // 10/22/17; It seems legit to sign the user out. The server told us the user was not on the system.
                        self.signUserOut()
                        Log.msg("signUserOut: FacebookSignIn: noUser in checkForExistingUser")
                        
                    case .owningUser:
                        // This should never happen!
                        // 10/22/17; Also legit to sign the user out -- a really odd case!
                        self.signUserOut()
                        Log.msg("signUserOut: FacebookSignIn: owningUser in checkForExistingUser")
                        Log.error("Somehow a Facebook user signed in as an owning user!!")
                        
                    case .sharingUser(sharingPermission: let permission, accessToken: let accessToken):
                        Log.msg("Sharing user signed in: access token: \(String(describing: accessToken))")
                        self.delegate?.userActionOccurred(action: .existingUserSignedIn(permission), signIn: self)
                        self.managerDelegate?.signInStateChanged(to: .signedIn, for: self)
                    }
                }
                else {
                    let message = "Error checking for existing user: \(error!)"
                    Log.error(message)
                    
                    // 10/22/17; It doesn't seem legit to sign user out if we're doing this during a launch sign-in. That is, the user was signed in last time the app launched. And this is a generic error (e.g., a network error). However, if we're not doing this during app launch, i.e., this is a sign-in request explicitly by the user, if that fails it means we're not already signed-in, so it's safe to force the sign out.
                    
                    if autoSignIn {
                        self.managerDelegate?.signInStateChanged(to: .signedIn, for: self)
                    }
                    else {
                        self.signUserOut()
                        Log.msg("signUserOut: FacebookSignIn: error in checkForExistingUser and not autoSignIn")
                        Alert.show(withTitle: "Alert!", message: message)
                    }
                }
            }
            
        case .createOwningUser:
            // Facebook users cannot be owning users! They don't have cloud storage.
            Alert.show(withTitle: "Alert!", message: "Somehow a Facebook user attempted to create an owning user!!")
            // 10/22/17; Seems legit. Very odd error situation.
            signUserOut()
            Log.msg("signUserOut: FacebookSignIn: tried to create an owning user!")
            
        case .createSharingUser(invitationCode: let invitationCode):
            SyncServerUser.session.redeemSharingInvitation(creds: credentials!, invitationCode: invitationCode) {[unowned self] longLivedAccessToken, error in
                if error == nil {
                    Log.msg("Facebook long-lived access token: \(String(describing: longLivedAccessToken))")
                    self.successCreatingSharingUser()
                }
                else {
                    Log.error("Error: \(error!)")
                    Alert.show(withTitle: "Alert!", message: "Error creating sharing user: \(error!)")
                    // 10/22/17; The common situation here seems to be the user is signing up via a sharing invitation. They are not on the system yet in that case. Seems safe to sign them out.
                    self.signUserOut()
                    Log.msg("signUserOut: FacebookSignIn: error in redeemSharingInvitation in")
                }
            }
            
        case .error:
            // 10/22/17; Error situation.
            self.signUserOut()
            Log.msg("signUserOut: FacebookSignIn: generic error in completeSignInProcess in")
        }
    }
}

private class FacebookSignInButton : UIControl, Tappable {
    var signInButton:LoginButton!
    weak var signIn: FacebookSyncServerSignIn!
    private let permissions = [ReadPermission.publicProfile]
    
    init() {
        // The parameters here are really unused-- I'm just using the FB LoginButton for it's visuals. I'm handling the actions myself because I need an indication of when the button is tapped, and can't seem to do that with FB's button. See the LoginManager below.
        signInButton = LoginButton(readPermissions: permissions)
        super.init(frame: signInButton.frame)
        addSubview(signInButton)
        signInButton.autoresizingMask = [.flexibleWidth]
        addTarget(self, action: #selector(tap), for: .touchUpInside)
        clipsToBounds = true
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        // The incoming point is relative to the coordinate system of the button if the button is at (0,0)
        var zeroStartFrame = frame
        zeroStartFrame.origin = CGPoint(x: 0, y: 0)
        if zeroStartFrame.contains(point) {
            return self
        }
        else {
            return nil
        }
    }
    
    @objc func tap() {
        if signIn.userIsSignedIn {
            signIn.signUserOut()
            Log.msg("signUserOut: FacebookSignIn: explicit request to signout")
        }
        else {
            signIn.managerDelegate?.signInStateChanged(to: .signInStarted, for: signIn)
            
            let loginManager = LoginManager()
            loginManager.logIn(readPermissions: permissions, viewController: nil) { (loginResult) in
                switch loginResult {
                case .failed(let error):
                    print(error)
                    // 10/22/17; This is an explicit sign-in request. User is not yet signed in. Seems legit to sign them out.
                    self.signIn.signUserOut()
                    Log.msg("signUserOut: FacebookSignIn: error during explicit request to signin")

                case .cancelled:
                    print("User cancelled login.")
                    // 10/22/17; User cancelled sign-in flow. Seems fine to sign them out.
                    self.signIn.signUserOut()
                    Log.msg("signUserOut: FacebookSignIn: user cancelled sign-in during explicit request to signin")

                case .success(_, _, _):
                    print("Logged in!")
                    
                    // Seems the UserProfile isn't loaded yet.
                    UserProfile.fetch(userId: AccessToken.current!.userId!) { fetchResult in
                        switch fetchResult {
                        case .success(_):
                            self.signIn.completeSignInProcess(autoSignIn: false)
                            
                        case .failed(let error):
                            let message = "Error fetching UserProfile: \(error)"
                            Alert.show(withTitle: "Alert!", message: message)
                            Log.error(message)
                            // 10/22/17; As above-- this is coming from an explicit request to sign the user in. Seems fine to sign them out after an error.
                            self.signIn.signUserOut()
                            Log.msg("signUserOut: FacebookSignIn: UserProfile.fetch failed during explicit request to signin")
                        }
                    }
                }
            }
        }
    }
}

#endif
