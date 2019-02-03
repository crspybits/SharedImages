//
//  PushNotifications.swift
//  SharedImages
//
//  Created by Christopher G Prince on 2/3/19
//  Copyright © 2019 Spastic Muffin, LLC. All rights reserved.
//

import Foundation
import UserNotifications
import PersistentValue
import SMCoreLib

class PushNotifications {
    // Just being cautious-- putting this in the keychain.
    private static let deviceToken = try! PersistentValue<Data>(name: "PushNotifications.deviceToken", storage: .keyChain)

    static let session = PushNotifications()
    
    // Some code adapted from: https://stackoverflow.com/questions/37956482/registering-for-push-notifications-in-xcode-8-swift-3-0
    func register(application: UIApplication) {        
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options:[.badge, .alert, .sound]) { (granted, error) in
            Log.msg("granted: \(granted)")

            guard error == nil else {
                Log.error("\(error!)")
                return
            }

            if granted {
                DispatchQueue.main.async {
                    application.registerForRemoteNotifications()
                }
            }
            else {
                Log.msg("User didn't grant Push Notifications")
            }
        }
    }
    
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {

        if PushNotifications.deviceToken.value == deviceToken {
            Log.msg("Device token unchanged.")
        }
        else {
            Log.msg("Device token changed: Updating in persistent store.")
            PushNotifications.deviceToken.value = deviceToken
            // Need to send this up to our servers.
        }

        let deviceTokenString = deviceToken.reduce("", {$0 + String(format: "%02X", $1)})
        Log.msg("Device token: \(deviceTokenString)")
        
        Log.msg("Device token 2: \(deviceToken)")
        Log.msg("Device token 3: \(String(describing: String(data: deviceToken, encoding: .utf8)))")
        Log.msg("Device token 4: \(deviceToken.description)")
        let token = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        Log.msg("Device token 5: \(token)")
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        Log.error("\(error)")
    }
    
    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable : Any]) {
        Log.msg("didReceiveRemoteNotification: \(userInfo)")
        SMCoreLib.Alert.show(withTitle: "Push Notification!", message: "Got a push notification: \(userInfo)")
    }
}
