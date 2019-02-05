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
    
    private var completionHandler: ((UIBackgroundFetchResult) -> Void)?
    
    private init() {}
    static let session = AppBadge()
    
    static func checkForBadgeAuthorization(usingViewController viewController:UIViewController) {
        func badgeAuthorization() {
            let notifCenter = UNUserNotificationCenter.current()
            // The first time this gets called, it will ask the user for authorization. Subsequent times, it's not called and just return the prior result.
            notifCenter.requestAuthorization(options:[.badge]) { (granted, error) in
                badgesAuthorized.boolValue = granted
                if error != nil {
                    Log.error("Error when requesting badge authorization: \(error!)")
                }
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
    
    func setBadge(completionHandler: ((UIBackgroundFetchResult) -> Void)?=nil) {
        // 10/31/17; Don't want to call server interface if a user is not signed in because (a) it makes no sense-- how can we interact with the server without a user signed in? and (b) because with the Facebook sign-in, the sign-in process itself causes the app to go into the background and we have badge setting itself operating if the app goes into the background-- and this all messes up the signin.
        Log.msg("AppBadge.setBadge")
        if AppBadge.badgesAuthorized.boolValue && SignInManager.session.userIsSignedIn {
            self.completionHandler = completionHandler
            ImagesHandler.session.syncEventAction = syncEvent
            
            Log.msg("AppBadge.setBadge: sync")
            do {
                try SyncServer.session.sync()
            } catch (let error) {
                Log.error("\(error)")
                completionHandler?(.failed)
                self.completionHandler = nil
                ImagesHandler.session.syncEventAction = nil
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

extension AppBadge {
    private func syncEvent(event: SyncControllerEvent) {
        func finish() {
            completionHandler?(.noData)
            completionHandler = nil
            ImagesHandler.session.syncEventAction = nil
        }
        
        switch event {
        case .syncDelayed:
            break
            
        case .syncDone:
            finish()
            
        case .syncError(message: let message):
            Log.error("\(message)")
            finish()
            
        case .syncStarted:
            break
            
        case .syncServerDown:
            finish()
        }
    }
}

