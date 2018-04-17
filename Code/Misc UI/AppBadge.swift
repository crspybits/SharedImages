//
//  AppBadge.swift
//  SharedImages
//
//  Created by Christopher Prince on 6/3/17.
//  Copyright © 2017 Spastic Muffin, LLC. All rights reserved.
//

import Foundation
import UIKit
import SMCoreLib
import UserNotifications
import SyncServer

class AppBadge {
    static var askedUserAboutBadges = SMPersistItemBool(name:"AppBadge.askedUserAboutBadges", initialBoolValue:false,  persistType: .userDefaults)
    static var badgesAuthorized = SMPersistItemBool(name:"AppBadge.badgesAuthorized", initialBoolValue:false,  persistType: .userDefaults)
    
    static func iOS9BadgeAuthorization(didRegister notificationSettings: UIUserNotificationSettings) {
        badgesAuthorized.boolValue = notificationSettings.types.contains(.badge)
    }
    
    static func checkForBadgeAuthorization(usingViewController viewController:UIViewController) {
        func badgeAuthorization() {
            if #available(iOS 10.0, *) {
                let notifCenter = UNUserNotificationCenter.current()
                // The first time this gets called, it will ask the user for authorization. Subsequent times, it's not called and just return the prior result.
                notifCenter.requestAuthorization(options:[.badge]) { (granted, error) in
                    badgesAuthorized.boolValue = granted
                    if error != nil {
                        Log.error("Error when requesting badge authorization: \(error!)")
                    }
                }
            }
            else {
                // iOS 9
                UIApplication.shared.registerUserNotificationSettings(UIUserNotificationSettings(types: [.badge], categories: nil))
            }
        }
        
        if AppBadge.askedUserAboutBadges.boolValue {
            badgeAuthorization()
        }
        else {
            AppBadge.askedUserAboutBadges.boolValue = true
            let alert = UIAlertController(title: "Would you like to know about images ready for download via a `badge` or count on the app icon?", message: "Then, answer `Allow` to the next prompt!", preferredStyle: .actionSheet)
            alert.popoverPresentationController?.sourceView = viewController.view
            Alert.styleForIPad(alert)

            alert.addAction(UIAlertAction(title: "Continue", style: .cancel) {alert in
                badgeAuthorization()
            })
            viewController.present(alert, animated: true, completion: nil)
        }
    }
    
    static func setBadge(completionHandler: ((UIBackgroundFetchResult) -> Void)?=nil) {
        // 10/31/17; Don't want to call `getStats` if a user is not signed in because (a) it makes no sense-- how can we interact with the server without a user signed in? and (b) because with the Facebook sign-in, the sign-in process itself causes the app to go into the background and we have badge setting itself operating if the app goes into the background-- and this all messes up the signin.
        if AppBadge.badgesAuthorized.boolValue && SignInManager.session.userIsSignedIn {
            SyncServer.session.getStats() { stats in
                if let stats = stats {
                    let total = stats.downloadDeletionsAvailable + stats.contentDownloadsAvailable
                    setBadge(number: total)
                    if total > 0 {
                        completionHandler?(.newData)
                    }
                    else {
                        completionHandler?(.noData)
                    }
                }
                else {
                    completionHandler?(.failed)
                }
            }
        }
        else {
            completionHandler?(.noData)
        }
    }
    
    // Set to 0 to hide badge.
    static func setBadge(number:Int) {
        if AppBadge.badgesAuthorized.boolValue {
            Thread.runSync(onMainThread: {
                UIApplication.shared.applicationIconBadgeNumber = number
            })
        }
    }
}
