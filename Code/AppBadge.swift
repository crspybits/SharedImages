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
        if AppBadge.badgesAuthorized.boolValue {
            SyncServer.session.getStats() { stats in
                if let stats = stats {
                    let total = stats.downloadDeletionsAvailable + stats.downloadsAvailable
                    UIApplication.shared.applicationIconBadgeNumber = total
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
}
