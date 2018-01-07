//
//  DropboxSignIn.swift
//  SyncServer
//
//  Created by Christopher Prince on 12/5/17.
//  Copyright © 2017 Spastic Muffin, LLC. All rights reserved.
//

// See the .podspec file for this definition.
#if SYNCSERVER_DROPBOX_SIGNIN

import Foundation
import SMCoreLib
import SwiftyDropbox
import SyncServer_Shared

// Purely for saving creds into NSUserDefaults
// NSObject subclass needed for NSCoding to work.
class DropboxSavedCreds : NSObject, NSCoding {
    // From the Dropbox docs: `The associated user`
    /* And at: https://www.dropbox.com/developers/documentation/http/documentation#users-get_account
     `uid String Deprecated. The API v1 user/team identifier. Please use account_id instead, or if using the Dropbox Business API, team_id.`
    */
    var uid: String!
    
    var displayName:String!
    var email:String!
    
    // This is what we're sending up the server. From the code docs from Dropbox: `The user's unique Dropbox ID.`
    var accountId: String!
    
    static private var data = SMPersistItemData(name: "DropboxSavedCreds.data", initialDataValue: Data(), persistType: .userDefaults)

    init(uid:String, accountId:String, displayName:String, email:String) {
        self.uid = uid
        self.accountId = accountId
        self.displayName = displayName
        self.email = email
    }
    
    func encode(with aCoder: NSCoder) {
        aCoder.encode(uid, forKey: "uid")
        aCoder.encode(accountId, forKey: "accountId")
        aCoder.encode(displayName, forKey: "displayName")
        aCoder.encode(email, forKey: "email")
    }
    
    required init?(coder aDecoder: NSCoder) {
        uid = aDecoder.decodeObject(forKey: "uid") as! String
        accountId = aDecoder.decodeObject(forKey: "accountId") as! String
        displayName = aDecoder.decodeObject(forKey: "displayName") as! String
        email = aDecoder.decodeObject(forKey: "email") as! String
    }
    
    func save() {
        let data = NSKeyedArchiver.archivedData(withRootObject: self)
        DropboxSavedCreds.data.dataValue = data
    }
    
    static func retrieve() -> DropboxSavedCreds? {
        if let object = NSKeyedUnarchiver.unarchiveObject(with: DropboxSavedCreds.data.dataValue) as? DropboxSavedCreds {
            return object
        }
        else {
            return nil
        }
    }
}

public class DropboxCredentials : GenericCredentials {
    var savedCreds:DropboxSavedCreds!
    var accessToken:String!
    
    init(savedCreds:DropboxSavedCreds, accessToken:String) {
        self.savedCreds = savedCreds
        self.accessToken = accessToken
    }
    
    // A unique identifier for the user. E.g., for Google this is their `sub`.
    public var userId:String {
        return savedCreds.uid
    }

    // This is sent to the server as a human-readable means to identify the user.
    public var username:String {
        return savedCreds.displayName
    }

    // A name suitable for identifying the user via the UI. If available this should be the users email. Otherwise, it could be the same as the username.
    public var uiDisplayName:String {
        return savedCreds.email
    }

    public var httpRequestHeaders:[String:String] {
        var result = [String:String]()
        result[ServerConstants.XTokenTypeKey] = ServerConstants.AuthTokenType.DropboxToken.rawValue
        result[ServerConstants.HTTPOAuth2AccessTokenKey] = accessToken
        result[ServerConstants.HTTPAccountIdKey] = savedCreds.accountId
        return result
    }

    // Dropbox doesn't have a creds refresh.
    public func refreshCredentials(completion: @escaping (SyncServerError?) ->()) {
        // Dropbox access tokens live until the user revokes them, so no need to refresh. See https://www.dropboxforum.com/t5/API-support/API-v2-access-token-validity/td-p/215123
        completion(.noRefreshAvailable)
    }
}

public class DropboxSyncServerSignIn : GenericSignIn {
    private var stickySignIn = false
    private var dropboxAccessToken:DropboxAccessToken?
    
    public var signOutDelegate:GenericSignOutDelegate?
    public var delegate:GenericSignInDelegate?
    public var managerDelegate:SignInManagerDelegate!
    private var signInOutButton:DropboxSignInButton?
    
    static private var accessToken:SMPersistItemString = SMPersistItemString(name: "DropboxSignIn.accessToken", initialStringValue: "", persistType: .keyChain)
    var accessToken:String? {
        set {
            if newValue == nil || newValue == "" {
                DropboxSyncServerSignIn.accessToken.stringValue = ""
            }
            else {
                DropboxSyncServerSignIn.accessToken.stringValue = newValue!
            }
        }
        get {
            if DropboxSyncServerSignIn.accessToken.stringValue.count == 0 {
                return nil
            }
            else {
                return DropboxSyncServerSignIn.accessToken.stringValue
            }
        }
    }
    
    public init(appKey: String) {
        DropboxClientsManager.setupWithAppKey(appKey)
    }
    
    public var signInTypesAllowed:SignInType = .owningUser
    
    public func appLaunchSetup(userSignedIn: Bool, withLaunchOptions options:[UIApplicationLaunchOptionsKey : Any]?) {

        if userSignedIn {
            if let creds = credentials {
                stickySignIn = true
                SyncServerUser.session.creds = creds
                
                // Can only autoSignIn with Dropbox if we have creds. No way to refresh it seems.
                autoSignIn()
            }
            else {
                // Doesn't seem much point in keeping the user with signed-in status if we don't have creds.
                signUserOut()
            }
        }
    }
    
    public func networkChangedState(networkIsOnline: Bool) {
        if stickySignIn && networkIsOnline && credentials == nil {
            Log.msg("DropboxSignIn: Trying autoSignIn...")
            autoSignIn()
        }
    }
    
    private func autoSignIn() {
        self.completeSignInProcess(autoSignIn: true)
    }
    
    public func application(_ app: UIApplication, open url: URL, options: [UIApplicationOpenURLOptionsKey : Any] = [:]) -> Bool {
    
        if let authResult = DropboxClientsManager.handleRedirectURL(url) {
            switch authResult {
            case .success(let dropboxAccessToken):
                Log.msg("Success! User is logged into Dropbox!")
                Log.msg("Dropbox: access token: \(dropboxAccessToken.accessToken)")
                Log.msg("Dropbox: uid: \(dropboxAccessToken.uid)")

                self.dropboxAccessToken = dropboxAccessToken
                
                // It seems we have to save the access token in the keychain, redundantly with Dropbox. I can't see a way to access it.
                accessToken = dropboxAccessToken.accessToken
                
                getCurrentAccountInfo()
                
            case .cancel:
                Log.msg("Authorization flow was manually canceled by user!")
                signUserOut()
                
            case .error(let oauth2Error, let description):
                Log.error("Error: \(description); oauth2Error: \(oauth2Error)")
                // This stemmed from an explicit sign-in request. It didn't complete successfully. Seems ok to sign out.
                signUserOut()
            }
            return true
        }

        return false
    }

    private func getCurrentAccountInfo() {
        if let client = DropboxClientsManager.authorizedClient {
            client.users.getCurrentAccount().response {[unowned self] (response: Users.FullAccount?, error) in
                
                Log.msg("Dropbox: getCurrentAccountInfo: response?.accountId: \(String(describing: response?.accountId))")
                
                // NOTE: This ^^^^ is *not* the same as the uid obtained when first signed in.
                
                if let usersFullAccount = response, error == nil {
                    let savedCreds = DropboxSavedCreds(uid: self.dropboxAccessToken!.uid,
                        accountId: usersFullAccount.accountId, displayName: usersFullAccount.name.displayName, email: usersFullAccount.email)
                    savedCreds.save()
                    self.completeSignInProcess(autoSignIn: false)
                } else {
                    // This stemmed from an explicit sign-in request.
                    self.signUserOut()
                    Log.error("Problem with getCurrentAccount: \(error!)")
                }
            }
        }
    }

    // The parameter must be given with key "viewController" and value, a `UIViewController` conforming object. Returns an object of type `DropboxSignInOutButton`.
    @discardableResult
    public func setupSignInButton(params:[String:Any]?) -> TappableButton? {        
        guard let vc = params?["viewController"] as? UIViewController else {
            Log.error("You must give a UIViewController conforming object with key `viewController`")
            return nil
        }
        
        signInOutButton = DropboxSignInButton(vc: vc, signIn: self)
        return signInOutButton
    }
    
    public var signInButton: TappableButton? {
        return signInOutButton
    }
    
    public var userIsSignedIn: Bool {
        return stickySignIn
    }

    public var credentials:GenericCredentials? {
        guard let savedCreds = DropboxSavedCreds.retrieve(), let accessToken = accessToken else {
            return nil
        }
        
        let creds = DropboxCredentials(savedCreds: savedCreds, accessToken: accessToken)
        return creds
    }

    public func signUserOut() {
        stickySignIn = false
        
        // I don't think this actually revokes the access token. Just clears it locally. Yes. Looking at their code, it just clears the keychain.
        DropboxClientsManager.unlinkClients()
        
        accessToken = nil
        
        signInOutButton?.buttonShowing = .signIn
        
        signOutDelegate?.userWasSignedOut(signIn: self)
        delegate?.userActionOccurred(action: .userSignedOut, signIn: self)
        managerDelegate?.signInStateChanged(to: .signedOut, for: self)
    }
    
    fileprivate func completeSignInProcess(autoSignIn:Bool) {
        signInOutButton?.buttonShowing = .signOut
        stickySignIn = true

        guard let userAction = delegate?.shouldDoUserAction(signIn: self) else {
            // This occurs if we don't have a delegate (e.g., on a silent sign in). But, we need to set up creds-- because this is what gives us credentials for connecting to the SyncServer.
            SyncServerUser.session.creds = credentials
            managerDelegate?.signInStateChanged(to: .signedIn, for: self)
            return
        }
        
        switch userAction {
        case .signInExistingUser:
            SyncServerUser.session.checkForExistingUser(creds: credentials!) { [unowned self]
                (checkForUserResult, error) in
                if error == nil {
                    switch checkForUserResult! {
                    case .noUser:
                        self.delegate?.userActionOccurred(action:
                            .userNotFoundOnSignInAttempt, signIn: self)
                        // 10/22/17; It seems legit to sign the user out. The server told us the user was not on the system.
                        self.signUserOut()
                        Log.msg("signUserOut: DropboxSignIn: noUser in checkForExistingUser")
                        
                    case .owningUser:
                        self.delegate?.userActionOccurred(action: .existingUserSignedIn(nil), signIn: self)
                        self.managerDelegate?.signInStateChanged(to: .signedIn, for: self)
                        self.signInOutButton?.buttonShowing = .signOut
                        
                    case .sharingUser:
                        // This should never happen.
                        Log.error("Can't have Dropbox sharing users.")
                        self.signUserOut()
                    }
                }
                else {
                    let message = "Error checking for existing user: \(error!)"
                    Log.error(message)
                    
                    // 10/22/17; It doesn't seem legit to sign user out if we're doing this during a launch sign-in. That is, the user was signed in last time the app launched. And this is a generic error (e.g., a network error). However, if we're not doing this during app launch, i.e., this is a sign-in request explicitly by the user, if that fails it means we're not already signed-in, so it's safe to force the sign out.
                    
                    if autoSignIn {
                        self.managerDelegate?.signInStateChanged(to: .signedIn, for: self)
                        self.signInOutButton?.buttonShowing = .signOut
                    }
                    else {
                        self.signUserOut()
                        Log.msg("signUserOut: DropboxSignIn: error in checkForExistingUser and not autoSignIn")
                        Alert.show(withTitle: "Alert!", message: message)
                    }
                }
            }
            
        case .createOwningUser:
            // We should always have non-nil credentials here. We'll get to here only in the non-autosign-in case (explicit request from user to create an account). In which case, we must have credentials.
            guard let creds = credentials else {
                signUserOut()
                SMCoreLib.Alert.show(withTitle: "Alert!", message: "Oh, yikes. Something bad has happened.")
                return
            }
            
            SyncServerUser.session.addUser(creds: creds) {[unowned self] error in
                if error == nil {
                    self.successCreatingOwningUser()
                }
                else {
                    SMCoreLib.Alert.show(withTitle: "Alert!", message: "Error creating owning user: \(error!)")
                    // 10/22/17; User is signing up. I.e., they don't have an account. Seems OK to sign them out.
                    self.signUserOut()
                    Log.msg("signUserOut: GoogleSignIn: createOwningUser error")
                }
            }
            
        case .createSharingUser:
            // Dropbox doesn't want to be an identity provider.
            Log.error("Can't have Dropbox sharing users.")
            self.signUserOut()
            
        case .error:
            // 10/22/17; Error situation.
            self.signUserOut()
            Log.msg("signUserOut: DropboxSignIn: generic error in completeSignInProcess in")
        }
    }
}

private class DropboxSignInButton : UIView, Tappable {
    weak var vc: UIViewController!
    weak var signIn: DropboxSyncServerSignIn!

    // Spans the entire UIView
    var button = UIButton(type: .system)
    
    var dropboxIconView:UIImageView!
    let label = UILabel()
    
    // 12/27/17; I was having problems getting this to be called at the right time (it was just in `layoutSubviews` at the time), so I separated it out into its own function.
    private func layout() {
        button.frame.size = frame.size
        
        if let dropboxIconView = dropboxIconView {
            dropboxIconView.frameX = 5
            dropboxIconView.centerVerticallyInSuperview()
            
            label.sizeToFit()
            let remainingWidth = frameWidth - dropboxIconView.frameMaxX
            label.centerX = dropboxIconView.frameMaxX + remainingWidth/2.0
            label.centerVerticallyInSuperview()
        }
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        layout()
    }
    
    override var frame: CGRect {
        set {
            super.frame = newValue
            layout()
        }
        
        get {
            return super.frame
        }
    }
    
    // Keeps only weak references to these parameters. You need to set the size of this button.
    init(vc: UIViewController, signIn: DropboxSyncServerSignIn) {
        super.init(frame: CGRect.zero)
        self.vc = vc
        self.signIn = signIn
        
        button.backgroundColor = .white
        addSubview(button)

        dropboxIconView = UIImageView(image: SMIcons.DropboxIcon)
        dropboxIconView.contentMode = .scaleAspectFit
        
        label.font = UIFont.boldSystemFont(ofSize: 14.0)
        
        button.addSubview(dropboxIconView)
        button.addSubview(label)
        button.addTarget(self, action: #selector(tap), for: .touchUpInside)
        
        // Otherwise, `didSet` doesn't get called in init methods. Odd.
        defer {
            // Can't just statically set this-- need to depend on sign-in state. Because on an autosign-in, the button gets allocated late in the process.
            buttonShowing = signIn.userIsSignedIn ? .signOut : .signIn
        }
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    @objc func tap() {
        switch buttonShowing {
        case .signIn:
            signIn.managerDelegate?.signInStateChanged(to: .signInStarted, for: signIn)
        
            DropboxClientsManager.authorizeFromController(UIApplication.shared,
                controller: vc, openURL: { url in
                UIApplication.shared.openURL(url)
            })
        case .signOut:
            signIn.signUserOut()
        }
    }
    
    enum State {
        case signIn
        case signOut
    }
    
    var buttonShowing:State = .signIn {
        didSet {
            Log.msg("Change sign-in state: \(buttonShowing)")
            switch buttonShowing {
            case .signIn:
                label.text = "Sign In"

            case .signOut:
                label.text = "Sign Out"
            }

            layout()
        }
    }
}

#endif
