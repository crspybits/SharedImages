
//
//  GenericSignIn.swift
//  SyncServer
//
//  Created by Christopher Prince on 6/23/17.
//  Copyright © 2017 Christopher Prince. All rights reserved.
//

import Foundation
import SyncServer_Shared
import SMCoreLib

public protocol GenericCredentials {    
    /// A unique identifier for the user for the specific account type. E.g., for Google this is their `sub`.
    var userId:String {get}

    /// This is sent to the server as a human-readable means to identify the user.
    var username:String {get}

    /// A name suitable for identifying the user via the UI. If available this should be the users email. Otherwise, it could be the same as the username.
    var uiDisplayName:String {get}

    var httpRequestHeaders:[String:String] {get}

    /// If your credentials scheme enables a refresh, i.e., on the credentials expiring.
    /// If your credentials scheme doesn't have a refresh capability, then immediately call the callback with a non-nil Error.
    func refreshCredentials(completion: @escaping (SyncServerError?) ->())
}

func equals(lhs: GenericCredentials, rhs: GenericCredentials) -> Bool {
    return lhs.userId == rhs.userId && type(of: lhs) == type(of: rhs)
}

public enum UserActionNeeded {
    case createSharingUser(invitationCode:String)
    case createOwningUser
    case signInExistingUser
    case error
}

public enum UserActionOccurred {
    case userSignedOut
    case userNotFoundOnSignInAttempt
    case existingUserSignedIn
    case sharingUserCreated(sharingGroupUUID: String)
    case owningUserCreated(sharingGroupUUID: String)
}

public protocol GenericSignOutDelegate : class {
    func userWasSignedOut(signIn:GenericSignIn)
}

public protocol GenericSignInDelegate : class {
    func shouldDoUserAction(signIn:GenericSignIn) -> UserActionNeeded
    
    /// Before calling this delegate method, the implementing code must present any UI alerts as needed. E.g., if an owning user was successfully created, present an alert to tell the user.
    func userActionOccurred(action:UserActionOccurred, signIn:GenericSignIn)
}

public enum SignInState {
    case signInStarted
    case signedIn
    case signedOut
}

public protocol SignInManagerDelegate : class {
    func signInStateChanged(to state: SignInState, for signIn:GenericSignIn)
}

/// A `UIView` is used to enable a broader description-- we're really thinking UIControl or UIButton.
public typealias TappableButton = UIView & Tappable
public protocol Tappable {
    /// The intent is that this will cause a touchUpInside action to be sent to the underlying button.
    func tap()
}

public protocol GenericSignIn : class {
    /// Some services, e.g., Facebook, are only suitable for sharing users-- i.e., they don't have cloud storage.
    var userType:UserType {get}
    
    /// For owning userType's, this gives the specific cloud storage type. For sharing userType's, this is nil.
    var cloudStorageType: CloudStorageType? {get}

    /// Delegate not dependent on the UI. Typically present through lifespan of app.
    var signOutDelegate:GenericSignOutDelegate? {get set}

    /// Delegate dependent on the UI. Typically present through only part of lifespan of app.
    var delegate:GenericSignInDelegate? {get set}
    
    /// Used exclusively by the SignInManager.
    var managerDelegate:SignInManagerDelegate! {get set}
    
    /// `userSignedIn`, when true, indicates that the user was signed-in with this GenericSignIn last time, and not signed out.
    func appLaunchSetup(userSignedIn: Bool, withLaunchOptions options:[UIApplication.LaunchOptionsKey : Any]?)
    
    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any]) -> Bool
    
    /// To enable sticky sign-in, and the GenericSignIn to refresh credentials if that wasn't possible at app launch, this will be called when network connectivity changes state.
    func networkChangedState(networkIsOnline: Bool)

    /// The UI element to use to allow signing in. A successful result will give a non-nil UI element. Each time this method is called, the same element instance is returned. Passing nil will bypass the parameters required if any.
    func setupSignInButton(params:[String:Any]?) -> TappableButton?
    
    /// Returns the last value returned from `setupSignInButton`.
    var signInButton: TappableButton? {get}
    
    /// Sign-in is sticky. Once signed-in, they tend to stay signed-in.
    var userIsSignedIn: Bool {get}

    /// Non-nil if userIsSignedIn is true.
    var credentials:GenericCredentials? {get}

    func signUserOut()
}

extension GenericSignIn {
    public func successCreatingOwningUser(sharingGroupUUID: String) {
        SMCoreLib.Alert.show(withTitle: "Success!", message: "Created new owning user! You are now signed in too!") { [unowned self] in
            // 12/27/17; I'm putting these delegate actions after the user taps OK so that we don't navigate away from the current view controller. That seems too fast in terms of UX, and can cause other problems.
            self.delegate?.userActionOccurred(action: .owningUserCreated(sharingGroupUUID: sharingGroupUUID), signIn: self)
            self.managerDelegate?.signInStateChanged(to: .signedIn, for: self)
        }
    }
    
    public func successCreatingSharingUser(sharingGroupUUID: String) {
        SMCoreLib.Alert.show(withTitle: "Success!", message: "Created new sharing user! You are now signed in too!") { [unowned self] in
            // 12/27/17; See above reasoning.
            self.delegate?.userActionOccurred(action: .sharingUserCreated(sharingGroupUUID: sharingGroupUUID), signIn: self)
            self.managerDelegate?.signInStateChanged(to: .signedIn, for: self)
        }
    }
}
