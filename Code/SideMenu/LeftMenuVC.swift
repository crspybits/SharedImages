//
//  LeftMenuVC.swift
//  SharedImages
//
//  Created by Christopher G Prince on 3/23/19.
//  Copyright © 2019 Spastic Muffin, LLC. All rights reserved.
//

import UIKit

class LeftMenuVC: UIViewController {
    static func create() -> LeftMenuVC {
        return UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "LeftMenuVC") as! LeftMenuVC
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    }
    
    enum CurrentScreen {
        case images
        case settings
        case signIn
    }
    
    var currentScreen: CurrentScreen? {
        switch SideMenu.session.rootViewController {
        case is AlbumsVC:
            return .images
        case is SettingsVC:
            return .settings
        case is SignInVC:
            return .signIn
        default:
            return nil
        }
    }
    
    @IBAction func imagesAction(_ sender: Any) {
        if currentScreen == .images {
            SideMenu.session.hideLeftMenu()
        }
        else {
            let albums = AlbumsVC.create()
            SideMenu.session.setRootViewController(albums)
        }
    }
    
    @IBAction func settingsAction(_ sender: Any) {
        if currentScreen == .settings {
            SideMenu.session.hideLeftMenu()
        }
        else {
            let settings = SettingsVC.create()
            SideMenu.session.setRootViewController(settings)
        }
    }
    
    @IBAction func signInAction(_ sender: Any) {
        if currentScreen == .signIn {
            SideMenu.session.hideLeftMenu()
        }
        else {
            let signIn = SignInVC.create()
            SideMenu.session.setRootViewController(signIn)
        }
    }
}
