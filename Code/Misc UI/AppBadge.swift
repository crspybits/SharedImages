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
    private var completionHandler: ((UIBackgroundFetchResult) -> Void)?
    
    private init() {}
    static let session = AppBadge()
    
    func setBadge(completionHandler: ((UIBackgroundFetchResult) -> Void)?=nil) {
        // 10/31/17; Don't want to call server interface if a user is not signed in because (a) it makes no sense-- how can we interact with the server without a user signed in? and (b) because with the Facebook sign-in, the sign-in process itself causes the app to go into the background and we have badge setting itself operating if the app goes into the background-- and this all messes up the signin.
        if Notifications.notificationsAuthorized.boolValue &&
            SignInManager.session.userIsSignedIn {
            self.completionHandler = completionHandler
            ImagesHandler.session.syncEventAction = syncEvent
            
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
        if Notifications.notificationsAuthorized.boolValue {
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

