//
//  Notifications.swift
//  SharedImages
//
//  Created by Christopher G Prince on 2/3/19
//  Copyright © 2019 Spastic Muffin, LLC. All rights reserved.
//

import Foundation
import UserNotifications
import PersistentValue
import SMCoreLib
import SyncServer

class Notifications {
    // Just being cautious-- putting this in the keychain.
    private static let deviceToken = try! PersistentValue<Data>(name: "PushNotifications.deviceToken", storage: .keyChain)
    static var askedUserAboutNotifications = SMPersistItemBool(name:"AppBadge.askedUserAboutBadges", initialBoolValue:false,  persistType: .userDefaults)
    static var notificationsAuthorized = SMPersistItemBool(name:"AppBadge.badgesAuthorized", initialBoolValue:false,  persistType: .userDefaults)
    
    static let session = Notifications()
    
    // Some code adapted from: https://stackoverflow.com/questions/37956482/registering-for-push-notifications-in-xcode-8-swift-3-0
    func register() {
        let center = UNUserNotificationCenter.current()
        // The first time this gets called, it will ask the user for authorization. Subsequent times, it's not called and just return the prior result.
        center.requestAuthorization(options:[.badge, .alert, .sound]) { (granted, error) in
            Log.info("granted: \(granted)")
            Notifications.notificationsAuthorized.boolValue = granted

            guard error == nil else {
                Log.error("\(error!)")
                return
            }

            if granted {
                DispatchQueue.main.async {
                    UIApplication.shared.registerForRemoteNotifications()
                }
            }
            else {
                Log.info("User didn't grant Push Notifications")
            }
        }
    }
    
    static func checkForNotificationAuthorization(usingViewController viewController:UIViewController) {
        
        if Notifications.askedUserAboutNotifications.boolValue {
            if Notifications.notificationsAuthorized.boolValue {
                Notifications.session.register()
            }
        }
        else {
            Notifications.askedUserAboutNotifications.boolValue = true
            
            let alert = UIAlertController(title: "Would you like notifications about new images and discussion comments?", message: "Then, answer `Allow` on the next prompt!", preferredStyle: Alert.prominentStyle())
            alert.popoverPresentationController?.sourceView = viewController.view
            Alert.styleForIPad(alert)

            alert.addAction(UIAlertAction(title: "OK", style: .default) { alert in
                Notifications.session.register()
            })
            
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { alert in
                // TODO: Eventually, we may want to have a Settings UI feature that reverses this-- otherwise, allowing notifications in the Apple Settings app will have no effect. OR-- is it possible to get an NSNotification about this user change?
                Notifications.notificationsAuthorized.boolValue = false
            })
            
            viewController.present(alert, animated: true, completion: nil)
        }
    }
    
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {

        let deviceTokenString = deviceToken.reduce("", {$0 + String(format: "%02X", $1)})
        Log.info("Device token: \(deviceTokenString)")
        
        Log.info("Device token 2: \(deviceToken)")
        Log.info("Device token 3: \(String(describing: String(data: deviceToken, encoding: .utf8)))")
        Log.info("Device token 4: \(deviceToken.description)")
        let token = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        Log.info("Device token 5: \(token)")

        if Notifications.deviceToken.value == deviceToken {
            Log.info("Device token unchanged.")
        }
        else {
            Log.info("Device token changed: Updating in persistent store.")
            
            SyncServerUser.session.registerPushNotificationToken(token: deviceTokenString) { error in
                guard error == nil else {
                    Log.error("\(error!)")
                    SMCoreLib.Alert.show(withTitle: "Alert!", message: "Could not register for push notifications.")
                    return
                }
                
                Notifications.deviceToken.value = deviceToken
            }
        }
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        Log.error("\(error)")
    }
    
    // Given [2] in AppDelegate, this is no longer needed or called.
    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable : Any]) {
        Log.info("didReceiveRemoteNotification: \(userInfo)")
        SMCoreLib.Alert.show(withTitle: "Push Notification!", message: "Got a push notification: \(userInfo)")
    }
}
