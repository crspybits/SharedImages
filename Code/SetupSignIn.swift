//
//  SetupSignIn.swift
//  SyncServer
//
//  Created by Christopher Prince on 12/2/16.
//  Copyright © 2016 Spastic Muffin, LLC. All rights reserved.
//

import Foundation
import SMCoreLib
import SyncServer

class SetupSignIn {
    static let session = SetupSignIn()
    
    var googleSignIn:GoogleSignIn!
    
    private init() {
    }
    
    func appLaunch() {
        var serverClientId:String!
        var appClientId:String!
        
        let plist = try! PlistDictLoader(plistFileNameInBundle: Consts.serverPlistFile)
        
        if case .stringValue(let value) = try! plist.getRequired(varName: "GoogleClientId") {
            appClientId = value
        }
        
        if case .stringValue(let value) = try! plist.getRequired(varName: "GoogleServerClientId") {
            serverClientId = value
        }
        
        googleSignIn = GoogleSignIn(serverClientId: serverClientId, appClientId: appClientId)
        googleSignIn.signOutDelegate = self
        SignInManager.session.addSignIn(googleSignIn)
    }
}

// I'm using this delegate to deal with this case: When we have an error refreshing credentials, and the SignInVC was not loaded, then we were not showing the user the sign in screen. They would otherwise be in a signed out state, but still be on the images screen.
extension SetupSignIn : GenericSignOutDelegate {
    func userWasSignedOut(signIn: GenericSignIn) {
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        appDelegate.selectTabInController(tab: .signIn)
    }
}

