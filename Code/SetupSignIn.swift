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
    
    var googleSignIn:GoogleSyncServerSignIn!
    var facebookSignIn:FacebookSyncServerSignIn!
    var dropboxSignIn:DropboxSyncServerSignIn!
    
    private init() {
    }
    
    func appLaunch(options: [UIApplication.LaunchOptionsKey: Any]?) {
        var serverClientId:String!
        var appClientId:String!
        var dropboxAppKey:String!

        let plist = try! PlistDictLoader(plistFileNameInBundle: Consts.serverPlistFile)
        
        if case .stringValue(let value) = try! plist.getRequired(varName: "GoogleClientId") {
            appClientId = value
        }
        
        if case .stringValue(let value) = try! plist.getRequired(varName: "GoogleServerClientId") {
            serverClientId = value
        }
        
        if case .stringValue(let value) = try! plist.getRequired(varName: "DropboxAppKey") {
            dropboxAppKey = value
        }
        
        // NOTE: When adding a new sign-in-- you need to add it here, and in SignInVC.swift.
        
        googleSignIn = GoogleSyncServerSignIn(serverClientId: serverClientId, appClientId: appClientId)
        googleSignIn.signOutDelegate = self
        SignInManager.session.addSignIn(googleSignIn, launchOptions: options)
        
        facebookSignIn = FacebookSyncServerSignIn()
        SignInManager.session.addSignIn(facebookSignIn, launchOptions: options)
        
        dropboxSignIn = DropboxSyncServerSignIn(appKey: dropboxAppKey)
        SignInManager.session.addSignIn(dropboxSignIn, launchOptions: options)
    }
}

// I'm using this delegate to deal with this case: When we have an error refreshing credentials, and the SignInVC was not loaded, then we were not showing the user the sign in screen. They would otherwise be in a signed out state, but still be on the images screen.
extension SetupSignIn : GenericSignOutDelegate {
    func userWasSignedOut(signIn: GenericSignIn) {
        if !(SideMenu.session.rootViewController is SignInVC) {
            let signIn = SignInVC.create()
            SideMenu.session.setRootViewController(signIn)
        }
    }
}

