//
//  LeftMenuVC.swift
//  SharedImages
//
//  Created by Christopher G Prince on 3/23/19.
//  Copyright © 2019 Spastic Muffin, LLC. All rights reserved.
//

import UIKit

class LeftMenuVC: UIViewController {
    @IBOutlet weak var topMenu: Menu!
    @IBOutlet weak var bottomMenu: Menu!
    
    static func create() -> LeftMenuVC {
        return UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "LeftMenuVC") as! LeftMenuVC
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let topMenuItems = [
            Menu.MenuItem(name: "Images", icon: #imageLiteral(resourceName: "albums"))
        ]
        
        topMenu.setup(items: topMenuItems, selection: {[unowned self] rowIndex in
            if self.currentScreen == .images {
                SideMenu.session.hideLeftMenu()
            }
            else {
                let albums = AlbumsVC.create()
                SideMenu.session.setRootViewController(albums)
            }
        })
        
//        let signInIcon = #imageLiteral(resourceName: "lock").withRenderingMode(.alwaysTemplate)
//        let bottomMenuItems = [
//            Menu.MenuItem(name: "Settings", icon: #imageLiteral(resourceName: "Settings")),
//            Menu.MenuItem(name: "Sign-In/Out", icon: signInIcon)
//        ]
//        
//        bottomMenu.setup(items: bottomMenuItems, selection: {[unowned self] rowIndex in
//        })
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

#if false
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
#endif
}
