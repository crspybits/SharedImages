
//
//  SignIn.swift
//  SyncServer
//
//  Created by Christopher Prince on 8/5/17.
//  Copyright © 2017 Christopher Prince. All rights reserved.
//

import UIKit
import SyncServer_Shared

public enum SignInUIState {
    /// asking if user wants to sign-in as existing or new user
    case initialSignInViewShowing
    
    /// view showing allows user to create a new (owning) user
    case createNewAccount
    
    /// view allowing user to sign in as existing user
    case existingAccount
}

enum ShowSignIns {
    case userType(UserType)
    case signedIn
}

public protocol SignInSubviewDelegate {
    func signInNavigateBack(_ signInSubView: UIView)
    func showSignIns(`for` account: SignInAccount, forSignInSubView: UIView)
}

public class SignIn : UIView {
    public var signInStart:SignInStart!
    public static var userInterfaceState:SignInUIState = .initialSignInViewShowing
    
    public override func awakeFromNib() {
        super.awakeFromNib()
        
        signInStart = SignInStart.createFromXib()!
        signInStart.delegate = self
        
        if SignInManager.session.userIsSignedIn {
            showSignIns(for: .signedIn)
        }
        else {
            addSubview(signInStart)
        }
    }
    
    public func showSignIns(`for` account: SignInAccount) {
        let signInAccounts:SignInAccounts = SignInAccounts.createFromXib()!
        signInAccounts.delegate = self
        
        var userType: UserType?

        switch account {
        case .existingAccount:
            SignIn.userInterfaceState = .existingAccount
            // Sign into an existing account-- which could be a either sharing or owning account type.
            userType = nil
            
        case .newAccount:
            SignIn.userInterfaceState = .createNewAccount
            // Overt creation of a new account is only allowed for owning users. To create a sharing user, you need an invitation.
            userType = .owning
            
        case .sharingAccount:
            // Allowing the user to sign in as a new sharing user. This is used only through an invitation. Could sign in as sharing or owning.
            SignIn.userInterfaceState = .createNewAccount
            userType = nil
            
        case .signedIn:
            // The user is already signed-in
            SignIn.userInterfaceState = .existingAccount
            userType = nil
        }
        
        var signIns = SignInManager.session.getSignIns(for: userType)
        if account == .signedIn {
            signIns = signIns.filter({$0.userIsSignedIn})
        }
        
        signInAccounts.currentSignIns = signIns
        signInAccounts.changeTitle(account)
        
        for view in subviews {
            view.removeFromSuperview()
        }
        
        addSubview(signInAccounts)
    }
}

extension SignIn: SignInSubviewDelegate {
    public func signInNavigateBack(_ signInSubView: UIView) {
        for view in subviews {
            view.removeFromSuperview()
        }
        
        if SignInManager.session.userIsSignedIn {
            showSignIns(for: .signedIn)
        }
        else {
            SignIn.userInterfaceState = .initialSignInViewShowing
            addSubview(signInStart)
        }
    }
    
    public func showSignIns(`for` account: SignInAccount, forSignInSubView: UIView) {
        showSignIns(for: account)
    }
}
