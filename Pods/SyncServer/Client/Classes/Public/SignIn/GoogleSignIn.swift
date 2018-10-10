
//
//  GoogleSignIn.swift
//  SyncServer
//
//  Created by Christopher Prince on 11/26/15.
//  Copyright © 2015 Christopher Prince. All rights reserved.
//

// See the .podspec file for this definition.
#if SYNCSERVER_GOOGLE_SIGNIN

import Foundation
import SMCoreLib
import SyncServer_Shared
import GoogleSignIn

public class GoogleCredentials : GenericCredentials, CustomDebugStringConvertible {
    public var userId:String = ""
    public var username:String = ""
    
    public var uiDisplayName:String {
        return email ?? username
    }
    
    public var email:String?
    
    fileprivate var currentlyRefreshing = false
    fileprivate var googleUser:GIDGoogleUser?

    var accessToken: String?
    
    // Used on the server to obtain a refresh code and an access token. The refresh token obtained on signin in the app can't be transferred to the server and used there.
    var serverAuthCode: String?
    
    public var httpRequestHeaders:[String:String] {
        var result = [String:String]()
        result[ServerConstants.XTokenTypeKey] = ServerConstants.AuthTokenType.GoogleToken.rawValue
        result[ServerConstants.HTTPOAuth2AccessTokenKey] = self.accessToken
        result[ServerConstants.HTTPOAuth2AuthorizationCodeKey] = self.serverAuthCode
        return result
    }
    
    public var debugDescription: String {
        return "Google Access Token: \(String(describing: accessToken))"
    }
    
    enum RefreshCredentialsResult : Error {
    case noGoogleUser
    }
    
    open func refreshCredentials(completion: @escaping (SyncServerError?) ->()) {
        // See also this on refreshing of idTokens: http://stackoverflow.com/questions/33279485/how-to-refresh-authentication-idtoken-with-gidsignin-or-gidauthentication
        
        guard self.googleUser != nil
        else {
            completion(.generic("No Google User"))
            return
        }
        
        Synchronized.block(self) {
            if self.currentlyRefreshing {
                return
            }
            
            self.currentlyRefreshing = true
        }
        
        Log.special("refreshCredentials")
        
        self.googleUser!.authentication.refreshTokens() { auth, error in
            self.currentlyRefreshing = false
            
            if error == nil {
                Log.special("refreshCredentials: Success")
                self.accessToken = auth!.accessToken
                completion(nil)
            }
            else {
                Log.error("Error refreshing tokens: \(error!)")
                // 10/22/17; It doesn't seem reasonable to sign the user out at this point, after a single attempt at refreshing credentials. If we have no network connection-- Why sign the user out then?
                completion(.credentialsRefreshError)
            }
        }
    }
}

// The class that you use to enable sign-in to Google should adopt this protocol. e.g., this should be the view controller on which your Google button is placed.
// Renaming `GIDSignInUIDelegate` to my own protocol just so we don't have to expose Google's
public protocol GoogleSignInUIProtocol : GIDSignInUIDelegate {
}

// See https://developers.google.com/identity/sign-in/ios/sign-in
public class GoogleSyncServerSignIn : NSObject, GenericSignIn {
    fileprivate var stickySignIn = false

    fileprivate let serverClientId:String!
    fileprivate let appClientId:String!
    
    fileprivate let signInOutButton = GoogleSignInOutButton()
    
    weak public var delegate:GenericSignInDelegate?    
    weak public var signOutDelegate:GenericSignOutDelegate?
    weak public var managerDelegate:SignInManagerDelegate!
    
    fileprivate var autoSignIn = true
   
    public init(serverClientId:String, appClientId:String) {
        self.serverClientId = serverClientId
        self.appClientId = appClientId
        super.init()
        self.signInOutButton.signOutButton.addTarget(self, action: #selector(signUserOut), for: .touchUpInside)
        signInOutButton.signIn = self
    }
    
    public var userType:UserType = .owning
    
    public func appLaunchSetup(userSignedIn: Bool, withLaunchOptions options:[UIApplicationLaunchOptionsKey : Any]?) {
    
        stickySignIn = userSignedIn
    
        // 7/30/17; Seems this is not needed any more using the GoogleSignIn Cocoapod; see https://stackoverflow.com/questions/44398121/google-signin-cocoapod-deprecated
        /*
        var configureError: NSError?
        GGLContext.sharedInstance().configureWithError(&configureError)
        assert(configureError == nil, "Error configuring Google services: \(String(describing: configureError))")
        */

        GIDSignIn.sharedInstance().delegate = self
        
        // Seem to need the following for accessing the serverAuthCode. Plus, you seem to need a "fresh" sign-in (not a silent sign-in). PLUS: serverAuthCode is *only* available when you don't do the silent sign in.
        // https://developers.google.com/identity/sign-in/ios/offline-access?hl=en
        GIDSignIn.sharedInstance().serverClientID = self.serverClientId
        GIDSignIn.sharedInstance().clientID = self.appClientId

        // 8/20/16; I had a difficult to resolve issue relating to scopes. I had re-created a file used by SharedNotes, outside of SharedNotes, and that application was no longer able to access the file. See https://developers.google.com/drive/v2/web/scopes The fix to this issue was in two parts: 1) to change the scope to access all of the users files, and to 2) force updating of the access_token/refresh_token on the server. (I did this later part by hand-- it would be good to be able to force this automatically).
        
        // "Per-file access to files created or opened by the app"
        // GIDSignIn.sharedInstance().scopes.append("https://www.googleapis.com/auth/drive.file")
        // I've also considered the Application Data Folder scope, but users cannot access the files in that-- which is against the goals in SyncServer.
        
        // "Full, permissive scope to access all of a user's files."
        GIDSignIn.sharedInstance().scopes.append("https://www.googleapis.com/auth/drive")
        
        // 12/20/15; Trying to resolve my user sign in issue
        // It looks like, at least for Google Drive, calling this method is sufficient for dealing with rcStaleUserSecurityInfo. I.e., having the IdToken for Google become stale. (Note that while it deals with the IdToken becoming stale, dealing with an expired access token on the server is a different matter-- and the server seems to need to refresh the access token from the refresh token to deal with this independently).
        // See also this on refreshing of idTokens: http://stackoverflow.com/questions/33279485/how-to-refresh-authentication-idtoken-with-gidsignin-or-gidauthentication
        
        autoSignIn = userSignedIn
        
        if userSignedIn {
            // I'm not sure if this is ever going to happen-- that we have non-nil creds on launch.
            if let creds = credentials {
                SyncServerUser.session.creds = creds
            }
            
            GIDSignIn.sharedInstance().signInSilently()
        }
        else {
            // I'm doing this to force a user-signout, so that I get the serverAuthCode. Seems I only get this with the user explicitly signed out before hand.
            GIDSignIn.sharedInstance().signOut()
        }
    }
    
    public func networkChangedState(networkIsOnline: Bool) {
        if stickySignIn && networkIsOnline && credentials == nil {
            autoSignIn = true
            Log.msg("GoogleSignIn: Trying autoSignIn...")
            GIDSignIn.sharedInstance().signInSilently()
        }
    }

    public func application(_ app: UIApplication, open url: URL, options: [UIApplicationOpenURLOptionsKey : Any] = [:]) -> Bool {
        let annotation = options[UIApplicationOpenURLOptionsKey.annotation]
        let sourceApplication = options[UIApplicationOpenURLOptionsKey.sourceApplication] as! String
        return GIDSignIn.sharedInstance().handle(url, sourceApplication: sourceApplication,
            annotation: annotation)
    }
    
    public var userIsSignedIn: Bool {
        return stickySignIn
    }
    
    public var credentials:GenericCredentials? {
        // hasAuthInKeychain can be true, and yet GIDSignIn.sharedInstance().currentUser can be nil. Seems to make more sense to test GIDSignIn.sharedInstance().currentUser.
        if GIDSignIn.sharedInstance().currentUser == nil {
            return nil
        }
        else {
            return signedInUser(forUser: GIDSignIn.sharedInstance().currentUser)
        }
    }
    
    func signedInUser(forUser user:GIDGoogleUser) -> GoogleCredentials {
        let name = user.profile.name
        let email = user.profile.email

        let creds = GoogleCredentials()
        creds.userId = user.userID
        creds.email = email
        creds.username = name!
        creds.accessToken = user.authentication.accessToken
        Log.msg("user.serverAuthCode: \(user.serverAuthCode)")
        creds.serverAuthCode = user.serverAuthCode
        creds.googleUser = user
        
        return creds
    }
    
    private var _signInOutButton: TappableButton?

    // The parameter must be given as "delegate" with a value of a `GoogleSignInUIProtocol` conforming object. Returns an object of type `GoogleSignInOutButton`.
    @discardableResult
    public func setupSignInButton(params:[String:Any]?) -> TappableButton? {        
        guard let delegate = params?["delegate"] as? GoogleSignInUIProtocol else {
            Log.error("You must give a GoogleSignInUIProtocol conforming object as a delegate parameter")
            return nil
        }
        
        GIDSignIn.sharedInstance().uiDelegate = delegate
        
        _signInOutButton = signInOutButton
        return signInOutButton
    }
    
    public var signInButton: TappableButton? {
        return _signInOutButton
    }
}

// // MARK: UserSignIn methods.
extension GoogleSyncServerSignIn {
    @objc public func signUserOut() {
        stickySignIn = false
        GIDSignIn.sharedInstance().signOut()
        signInOutButton.buttonShowing = .signIn
        managerDelegate?.signInStateChanged(to: .signedOut, for: self)
        signOutDelegate?.userWasSignedOut(signIn: self)
        delegate?.userActionOccurred(action: .userSignedOut, signIn: self)
    }
}

extension GoogleSyncServerSignIn : GIDSignInDelegate {
    public func sign(_ signIn: GIDSignIn!, didSignInFor user: GIDGoogleUser!, withError error: Error!)
    {
        if (error == nil) {
            self.signInOutButton.buttonShowing = .signOut
            let creds = signedInUser(forUser: user)
            stickySignIn = true
            
            guard let userAction = self.delegate?.shouldDoUserAction(signIn: self) else {
                // This occurs if we don't have a delegate (e.g., on a silent sign in). But, we need to set up creds-- because this is what gives us credentials for connecting to the SyncServer.
                SyncServerUser.session.creds = creds
                managerDelegate?.signInStateChanged(to: .signedIn, for: self)
                return
            }

            // TODO: *0* Put up a spinner-- if we have an error, it can take a while.
            
            switch userAction {
            case .signInExistingUser:
                SyncServerUser.session.checkForExistingUser(creds: creds) {[unowned self]
                    (checkForUserResult, error) in
                    if error == nil {
                        switch checkForUserResult! {
                        case .noUser:
                            self.delegate?.userActionOccurred(action:
                                .userNotFoundOnSignInAttempt, signIn: self)
                            // 10/22/17; It seems legit to sign the user out. The server told us the user was not on the system.
                            self.signUserOut()
                            Log.msg("signUserOut: GoogleSignIn: noUser")

                        case .user(_):
                            self.delegate?.userActionOccurred(action:
                                .existingUserSignedIn, signIn: self)
                            self.managerDelegate?.signInStateChanged(to: .signedIn, for: self)
                        }
                    }
                    else {
                        let message = "Error checking for existing user: \(error!)"
                        Log.error(message)

                        if self.autoSignIn {
                            self.managerDelegate?.signInStateChanged(to: .signedIn, for: self)
                        }
                        else {
                            // 10/22/17; See reasoning in FacebookSignIn at about this point in the code for signUserOut issue.
                            self.signUserOut()
                            Log.msg("signUserOut: GoogleSignIn: error in checkForExistingUser but not autoSignIn")
                            SMCoreLib.Alert.show(withTitle: "Alert!", message: message)
                        }
                    }
                }

            case .createOwningUser:
                let sharingGroupUUID = UUID().uuidString
                SyncServerUser.session.addUser(creds: creds, sharingGroupUUID: sharingGroupUUID, sharingGroupName: nil) {[unowned self] error in
                    if error == nil {
                        self.successCreatingOwningUser(sharingGroupUUID: sharingGroupUUID)
                    }
                    else {
                        SMCoreLib.Alert.show(withTitle: "Alert!", message: "Error creating owning user: \(error!)")
                        // 10/22/17; User is signing up. I.e., they don't have an account. Seems OK to sign them out.
                        self.signUserOut()
                        Log.msg("signUserOut: GoogleSignIn: createOwningUser error")
                    }
                }
                
            case .createSharingUser(invitationCode: let invitationCode):
                SyncServerUser.session.redeemSharingInvitation(creds: creds, invitationCode: invitationCode, cloudFolderName: SyncServerUser.session.cloudFolderName) {[unowned self] accessToken, sharingGroupUUID, error in
                    if error == nil, let sharingGroupUUID = sharingGroupUUID {
                        self.successCreatingSharingUser(sharingGroupUUID: sharingGroupUUID)
                    }
                    else {
                        SMCoreLib.Alert.show(withTitle: "Alert!", message: "Error creating sharing user: \(error!)")
                        // 10/22/17; User is signing up. I.e., they don't have an account. Seems OK to sign them out.
                        self.signUserOut()
                        Log.msg("signUserOut: GoogleSignIn: redeemSharingInvitation error")
                    }
                }
            
            case .error:
                // 10/22/17; Error situation.
                self.signUserOut()
                Log.msg("signUserOut: GoogleSignIn: generic error")
            }
        }
        else {
            let message = "Error signing into Google: \(error!)"
            Log.error(message)
            
            // 10/22/17; Not always signing the user out here. It doesn't make sense if we get an error during launch. It doesn't make sense if we're attempting to do a creds refresh automatically when the app is running. It can make sense, however, if this is an explicit request by the user to sign-in.
            
            // See https://github.com/crspybits/SharedImages/issues/64
            /* From the delegate, error is actually an NSError:
                        - (void)signIn:(GIDSignIn *)signIn
                didSignInForUser:(GIDGoogleUser *)user
                       withError:(NSError *)error;
            */
            var haveAuthToken = true
            if let error = error as NSError?, error.code == -4  {
                haveAuthToken = false
                Log.msg("GIDSignIn: Got a -4 error code")
            }
            
            if !haveAuthToken || !autoSignIn {
                // Must be an explicit request by user.
                signUserOut()
                Log.msg("signUserOut: GoogleSignIn: error in didSignInFor delegate and not autoSignIn")
                
                // This assumes there is a root view controller present-- don't do it during auto sign-in.
                SMCoreLib.Alert.show(withTitle: "Alert!", message: message)
            }
            else {
                self.signInOutButton.buttonShowing = .signOut
                self.managerDelegate?.signInStateChanged(to: .signedIn, for: self)
            }
        }
        
        autoSignIn = false
    }
    
    // TODO: *2* When does this get called?
    public func sign(_ signIn: GIDSignIn!, didDisconnectWith user: GIDGoogleUser!, withError error: Error!)
    {
    }
}

// Self-sized; cannot be resized.
private class GoogleSignInOutButton : UIView, Tappable {
    let signInButton = GIDSignInButton()
    
    let signOutButtonContainer = UIView()
    let signOutContentView = UIView()
    let signOutButton = UIButton(type: .system)
    let signOutLabel = UILabel()
    
    weak var signIn: GoogleSyncServerSignIn!

    init() {
        super.init(frame: CGRect.zero)
        self.addSubview(signInButton)
        self.addSubview(self.signOutButtonContainer)
        
        self.signOutButtonContainer.addSubview(self.signOutContentView)
        self.signOutButtonContainer.addSubview(signOutButton)
       
        let googleIconView = UIImageView(image: SMIcons.GoogleIcon)
        googleIconView.contentMode = .scaleAspectFit
        self.signOutContentView.addSubview(googleIconView)
        
        self.signOutLabel.text = "Sign out"
        self.signOutLabel.font = UIFont.boldSystemFont(ofSize: 15.0)
        self.signOutLabel.sizeToFit()
        self.signOutContentView.addSubview(self.signOutLabel)
        
        let frame = signInButton.frame
        self.bounds = frame
        self.signOutButton.frame = frame
        self.signOutButtonContainer.frame = frame
        
        let margin:CGFloat = 20
        self.signOutContentView.frame = frame
        self.signOutContentView.frameHeight -= margin
        self.signOutContentView.frameWidth -= margin
        self.signOutContentView.centerInSuperview()
        
        let iconSize = frame.size.height * 0.4
        googleIconView.frameSize = CGSize(width: iconSize, height: iconSize)
        
        googleIconView.centerVerticallyInSuperview()
        
        self.signOutLabel.frameMaxX = self.signOutContentView.boundsMaxX
        self.signOutLabel.centerVerticallyInSuperview()

        let layer = self.signOutButton.layer
        layer.borderColor = UIColor.lightGray.cgColor
        layer.borderWidth = 0.5
        
        self.buttonShowing = .signIn
        
        signInButton.addTarget(self, action: #selector(signInButtonAction), for: .touchUpInside)
        
        signOutButtonContainer.backgroundColor = UIColor.white
    }
    
    @objc func signInButtonAction() {
        if buttonShowing == .signIn {
            signIn.managerDelegate.signInStateChanged(to: .signInStarted, for: signIn)
        }
    }
    
    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override public func layoutSubviews() {
        super.layoutSubviews()
    }
    
    enum State {
        case signIn
        case signOut
    }

    fileprivate var _state:State!
    var buttonShowing:State {
        get {
            return self._state
        }
        
        set {
            Log.msg("Change sign-in state: \(newValue)")
            self._state = newValue
            switch self._state! {
            case .signIn:
                self.signInButton.isHidden = false
                self.signOutButtonContainer.isHidden = true
            
            case .signOut:
                self.signInButton.isHidden = true
                self.signOutButtonContainer.isHidden = false
            }
            
            self.setNeedsDisplay()
        }
    }
    
    func tap() {
        switch buttonShowing {
        case .signIn:
            self.signInButton.sendActions(for: .touchUpInside)
            
        case .signOut:
            self.signOutButton.sendActions(for: .touchUpInside)
        }
    }
}

#endif
