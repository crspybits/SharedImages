//
//  TabControllerDelegate.swift
//  SharedImages
//
//  Created by Christopher Prince on 3/12/17.
//  Copyright © 2017 Spastic Muffin, LLC. All rights reserved.
//

import Foundation
import UIKit
import SyncServer

class TabControllerDelegate : NSObject, UITabBarControllerDelegate {
    func tabBarController(_ tabBarController: UITabBarController, shouldSelect viewController: UIViewController) -> Bool {

        // Only allow a transition to the Albums screen if the user is signed in.
        if viewController.restorationIdentifier == "AlbumsNavController" {
            return SignInManager.session.userIsSignedIn
        }
        
        return true
    }
}

