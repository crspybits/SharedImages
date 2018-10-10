
//
//  SignInManager.swift
//  SyncServer
//
//  Created by Christopher Prince on 6/23/17.
//  Copyright © 2017 Christopher Prince. All rights reserved.
//

import Foundation
import SMCoreLib
import SyncServer_Shared

// This class needs to be derived from NSObject because of use of `Network.session().connectionStateCallbacks` below.
public class SignInManager : NSObject {
    /// These must be stored in user defaults-- so that if they delete the app, we lose it, and can start again. Storing both the currentUIDisplayName and userId because the userId (at least for Google) is just a number and not intelligible in the UI.
    public static var currentUIDisplayName = SMPersistItemString(name:"SignInManager.currentUIDisplayName", initialStringValue:"",  persistType: .userDefaults)
    public static var currentUserId = SMPersistItemString(name:"SignInManager.currentUserId", initialStringValue:"",  persistType: .userDefaults)
    
    /// The class name of the current GenericSignIn
    static var currentSignInName = SMPersistItemString(name:"SignInManager.currentSignIn", initialStringValue:"", persistType: .userDefaults)

    public static let session = SignInManager()
    
    public var signInStateChanged:TargetsAndSelectors = NSObject()
    public fileprivate(set) var lastStateChangeSignedUserIn = false
    
    private override init() {
        super.init()
        signInStateChanged.resetTargets!()
        _ = Network.session().connectionStateCallbacks.addTarget!(self, with: #selector(networkChangedState))
    }
    
    @objc private func networkChangedState() {
        let networkOnline = Network.session().connected()
        for signIn in alternativeSignIns {
            signIn.networkChangedState(networkIsOnline: networkOnline)
        }
    }
    
    fileprivate var alternativeSignIns = [GenericSignIn]()
    
    // Pass userType of nil for both sharing and owning.
    public func getSignIns(`for` userType: UserType?) -> [GenericSignIn]  {
        var result = [GenericSignIn]()
        
        for signIn in alternativeSignIns {
            switch userType {
            case .none:
                result += [signIn]
            case .some(.sharing):
                // Owning user types can also be sharing, i.e., it doesn't matter what the signIn.userType is when the ask is for sharing sign ins.
                result += [signIn]
            case .some(.owning):
                // But purely sharing user types (e.g., Facebook) cannot be owning.
                if signIn.userType == .owning {
                    result += [signIn]
                }
            }
        }
        
        return result
    }
    
    /// Set this to establish the current SignIn mechanism in use in the app.
    public var currentSignIn:GenericSignIn? {
        didSet {
            if currentSignIn == nil {
                SyncServerUser.session.creds = nil
                SignInManager.currentSignInName.stringValue = ""
            }
            else {
                SignInManager.currentSignInName.stringValue = stringNameForSignIn(currentSignIn!)
            }
        }
    }
    
    fileprivate func stringNameForSignIn(_ signIn: GenericSignIn) -> String {
        // This gives "GenericSignIn"
        // String(describing: type(of: currentSignIn!))
        
        let mirror = Mirror(reflecting: signIn)
        return "\(mirror.subjectType)"
    }
    
    /// A shorthand-- because it's often used.
    public var userIsSignedIn:Bool {
        return currentSignIn != nil && currentSignIn!.userIsSignedIn
    }
    
    /// At launch, you must set up all the SignIn's that you'll be presenting to the user. This will call their `appLaunchSetup` method.
    public func addSignIn(_ signIn:GenericSignIn, launchOptions options: [UIApplicationLaunchOptionsKey: Any]?) {
        // Make sure we don't already have an instance of this signIn
        let name = stringNameForSignIn(signIn)
        let result = alternativeSignIns.filter({stringNameForSignIn($0) == name})
        assert(result.count == 0)
        
        alternativeSignIns.append(signIn)
        signIn.managerDelegate = self
        
        func userSignedIn(withSignInName name: String) -> Bool {
            return SignInManager.currentSignInName.stringValue == name
        }
        
        signIn.appLaunchSetup(userSignedIn: userSignedIn(withSignInName: name), withLaunchOptions: options)
        
        // 12/3/17; In some cases, the `userSignedIn` state can change with the call `appLaunchSetup`-- so, recompute userSignedIn each time. This is related to the fix for https://github.com/crspybits/SharedImages/issues/64
        
        // To accomodate sticky sign-in's-- we might as well have a `currentSignIn` value immediately after addSignIn's are called.
        if userSignedIn(withSignInName: name) {
            currentSignIn = signIn
        }
    }
    
    /// Based on the currently active signin method, this will call the corresponding method on that class.
    public func application(_ app: UIApplication, open url: URL, options: [UIApplicationOpenURLOptionsKey : Any] = [:]) -> Bool {
        
        for signIn in alternativeSignIns {
            if SignInManager.currentSignInName.stringValue == stringNameForSignIn(signIn) {
                return signIn.application(app, open: url, options: options)
            }
        }
        
        // 10/1/17; Up until today, I had this assert here. For some reason, I was assuming that if I got a `open url` call, the user *had* to be signed in. But this is incorrect. For example, I could get a call for a sharing invitation.
        // assert(false)
        
        return false
    }
}

extension SignInManager : SignInManagerDelegate {
    public func signInStateChanged(to state: SignInState, for signIn:GenericSignIn) {
        let priorSignIn = currentSignIn
        
        switch state {
        case .signInStarted:
            // Must not have any other signin's active when attempting to sign in.
            assert(currentSignIn == nil)
            // This is necessary to enable the `application(_ application: UIApplication!,...` method to be called during the sign in process.
            currentSignIn = signIn
            
        case .signedIn:
            // This is necessary for silent sign in's.
            currentSignIn = signIn
            
        case .signedOut:
            currentSignIn = nil
        }
        
        lastStateChangeSignedUserIn = priorSignIn == nil && currentSignIn != nil
        
        signInStateChanged.forEachTarget!() { (target, selector, dict) in
            if let targetObject = target as? NSObject {
                targetObject.performVoidReturn(selector)
            }
        }
    }
}

