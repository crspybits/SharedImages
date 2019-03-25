//
//  LeftMenuVC.swift
//  SharedImages
//
//  Created by Christopher G Prince on 3/23/19.
//  Copyright © 2019 Spastic Muffin, LLC. All rights reserved.
//

import UIKit
import LGSideMenuController
import SyncServer

class LeftMenuVC: UIViewController {
    @IBOutlet private weak var topMenuContainer: UIView!
    @IBOutlet weak var topMenuHeight: NSLayoutConstraint!
    @IBOutlet private weak var bottomMenuContainer: UIView!
    @IBOutlet weak var bottomMenuHeight: NSLayoutConstraint!
    private let topMenu = Menu.create()!
    private let bottomMenu = Menu.create()!

    static func create() -> LeftMenuVC {
        return UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "LeftMenuVC") as! LeftMenuVC
    }
    
    private func menuAction(screen: CurrentScreen, newVC:()->(UIViewController)) {
        if self.currentScreen == screen {
            SideMenu.session.hideLeftMenu()
        }
        else {
            let vc = newVC()
            SideMenu.session.setRootViewController(vc)
        }
    }
    
    private func setup() {
        let numberUnreadDiscussions:()->(Int?) = {
            let total = Discussion.totalUnreadCount()
            if total == 0 {
                return nil
            }
            else {
                return total
            }
        }
        
        let topMenuItems = [
            Menu.MenuItem(name: "Images", icon: #imageLiteral(resourceName: "albums"), badgeValueGetter: numberUnreadDiscussions)
        ]

        topMenu.setup(items: topMenuItems, selection: {[unowned self] rowIndex in
            guard self.canUseOtherMenus() else {
                self.topMenu.setSelectedRowIndex(nil, animated: false)
                return
            }
            
            if self.bottomMenu.selectedRowIndex == nil {
                self.menuAction(screen: .images, newVC: { AlbumsVC.create() })
            }
            else {
                self.bottomMenu.selectedRowIndex = nil
                DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + DispatchTimeInterval.milliseconds(300)) {
                    self.menuAction(screen: .images, newVC: { AlbumsVC.create() })
                }
            }
        })
        
        topMenu.frameWidth = topMenuContainer.frameWidth
        topMenuHeight.constant = topMenu.contentHeight
        topMenu.frameHeight = topMenu.contentHeight
        topMenuContainer.addSubview(topMenu)
        
        let signInIcon = #imageLiteral(resourceName: "lock").withRenderingMode(.alwaysTemplate)
        let bottomMenuItems = [
            Menu.MenuItem(name: "Settings", icon: #imageLiteral(resourceName: "Settings")),
            Menu.MenuItem(name: "Sign-In/Out", icon: signInIcon)
        ]

        bottomMenu.setup(items: bottomMenuItems, selection: {[unowned self] rowIndex in
            let screenIndex = UInt(rowIndex) + CurrentScreen.settingsStartIndex
            
            guard let screen = CurrentScreen(rawValue: screenIndex) else {
                return
            }
            
            func changeMenu() {
                switch screen {
                case .settings:
                    guard self.canUseOtherMenus() else {
                        self.bottomMenu.setSelectedRowIndex(CurrentScreen.signIn.rawValue - CurrentScreen.settingsStartIndex, animated: false)
                        return
                    }
            
                    self.menuAction(screen: screen, newVC: { SettingsVC.create() })
                    
                case .signIn:
                    self.menuAction(screen: screen, newVC: { SignInVC.create() })

                default:
                    return
                }
            }
            
            if self.topMenu.selectedRowIndex == nil {
                changeMenu()
            }
            else {
                self.topMenu.selectedRowIndex = nil
                DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + DispatchTimeInterval.milliseconds(300)) {
                    changeMenu()
                }
            }
        })

        bottomMenu.frameWidth = bottomMenuContainer.frameWidth
        bottomMenuHeight.constant = bottomMenu.contentHeight
        bottomMenu.frameHeight = bottomMenu.contentHeight
        bottomMenuContainer.addSubview(bottomMenu)
        
        NotificationCenter.default.addObserver(self, selector: #selector(leftMenuWillShow), name: NSNotification.Name.LGSideMenuWillShowLeftView, object: nil)
    }
    
    // If there are no images in the app, and no albums, and not signed, then don't allow navigation away from SignIn screen --> Don't want them them getting the "allow notifications" questions in that case.
    private func canUseOtherMenus() -> Bool {
        let sharingGroups = SyncServer.session.sharingGroups
        return SignInManager.session.userIsSignedIn || (sharingGroups.count > 1 || Image.fetchAll().count > 0)
    }
    
    @objc private func leftMenuWillShow() {
        topMenu.refreshBadges()
        
        // So, on (e.g., first) menu opening, we have a menu item selected. And it's the right menu item.
        guard let currentScreen = currentScreen else {
            return
        }
        
        topMenu.setSelectedRowIndex(nil, animated: false)
        bottomMenu.setSelectedRowIndex(nil, animated: false)
        
        switch currentScreen {
        case .images:
            topMenu.setSelectedRowIndex(CurrentScreen.images.rawValue, animated: false)
            
        case .settings:
            bottomMenu.setSelectedRowIndex(CurrentScreen.settings.rawValue - CurrentScreen.settingsStartIndex, animated: false)

        case .signIn:
            bottomMenu.setSelectedRowIndex(CurrentScreen.signIn.rawValue - CurrentScreen.settingsStartIndex, animated: false)
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    private var shouldSetup = true
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        if shouldSetup {
            shouldSetup = false
            setup()
        }
    }
    
    enum CurrentScreen: UInt {
        // Ordering in top menu
        case images = 0
        
        // Needs to be the same as the value for `settings`
        static let settingsStartIndex:UInt = 1
        
        // Ordering in lower menu
        case settings = 1
        case signIn = 2
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
}
