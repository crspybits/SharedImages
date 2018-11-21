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
    
    private var priorEventsDesired: EventDesired!
    private var priorDelegate: SyncServerDelegate!
    private var completionHandler: ((UIBackgroundFetchResult) -> Void)?
    
    private init() {}
    static let session = AppBadge()
    
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
    
    func setBadge(completionHandler: ((UIBackgroundFetchResult) -> Void)?=nil) {
        // 10/31/17; Don't want to call server interface if a user is not signed in because (a) it makes no sense-- how can we interact with the server without a user signed in? and (b) because with the Facebook sign-in, the sign-in process itself causes the app to go into the background and we have badge setting itself operating if the app goes into the background-- and this all messes up the signin.
        if AppBadge.badgesAuthorized.boolValue && SignInManager.session.userIsSignedIn {
            priorDelegate = SyncServer.session.delegate
            priorEventsDesired = SyncServer.session.eventsDesired
            
            SyncServer.session.delegate = self
            SyncServer.session.eventsDesired = [.syncDone]
            self.completionHandler = completionHandler
            
            do {
                try SyncServer.session.sync()
            } catch (let error) {
                Log.error("\(error)")
                SyncServer.session.delegate = priorDelegate
                SyncServer.session.eventsDesired = priorEventsDesired
                completionHandler?(.failed)
                self.completionHandler = nil
                return
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

extension AppBadge: SyncServerDelegate {
    func syncServerFileGroupDownloadGone(group: [DownloadOperation]) {
    }
    
    func syncServerSharingGroupsDownloaded(created: [SyncServer.SharingGroup], updated: [SyncServer.SharingGroup], deleted: [SyncServer.SharingGroup]) {
    }
    
    func syncServerMustResolveContentDownloadConflict(_ downloadContent: ServerContentType, downloadedContentAttributes: SyncAttributes, uploadConflict: SyncServerConflict<ContentDownloadResolution>) {
    }
    
    func syncServerMustResolveDownloadDeletionConflicts(conflicts: [DownloadDeletionConflict]) {
    }
    
    func syncServerFileGroupDownloadComplete(group: [DownloadOperation]) {
    }
    
    func syncServerErrorOccurred(error: SyncServerError) {
    }
    
    func syncServerEventOccurred(event: SyncEvent) {
        switch event {
        case .syncDone:
            let syncNeeded = SyncServer.session.sharingGroups.filter {$0.syncNeeded!}
            AppBadge.setBadge(number: syncNeeded.count)
            
            SyncServer.session.delegate = priorDelegate
            SyncServer.session.eventsDesired = priorEventsDesired
            completionHandler?(.noData)
            completionHandler = nil
            
        default:
            break
        }
    }
}

