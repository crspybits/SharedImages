//
//  AppDelegate.swift
//  SharedImages
//
//  Created by Christopher Prince on 3/8/17.
//  Copyright © 2017 Spastic Muffin, LLC. All rights reserved.
//

import UIKit
import CoreData
import SMCoreLib
import SyncServer
import Fabric
import Crashlytics
import rosterdev
import UserNotifications

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?
    var tabBarDelegate = TabControllerDelegate()
    var tabBarController:UITabBarController!
    var sharingDelegate:SharingInviteDelegate?
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
    
#if DEBUG
        Log.minLevel = .verbose
#else
        Log.minLevel = .error
#endif

#if DEBUG
        TestCases.setup()
#endif
    
        let plist = try! PlistDictLoader(plistFileNameInBundle: Consts.serverPlistFile)
        
        Environment.setup()
        
        var serverURL:URL
        var cloudFolderName:String
        var failoverURL:URL?
        
        switch Environment.current {
        case .production:
            let urlString = try! plist.getString(varName: "ServerURL")
            serverURL = URL(string: urlString)!
            cloudFolderName = try! plist.getString(varName: "CloudFolderName")
            if let failoverURLString = try? plist.getString(varName: "FailoverMessageURL") {
                failoverURL = URL(string: failoverURLString)
            }
            
        // Only used in debug builds.
        case .staging:
            let urlString = try! plist.getString(varName: "StagingServerURL")
            serverURL = URL(string: urlString)!
            cloudFolderName = try! plist.getString(varName: "StagingCloudFolderName")
            if let failoverURLString = try? plist.getString(varName: "StagingFailoverMessageURL") {
                failoverURL = URL(string: failoverURLString)
            }
        
        case .local:
            let urlString = try! plist.getString(varName: "LocalServerURL")
            serverURL = URL(string: urlString)!
            cloudFolderName = try! plist.getString(varName: "LocalCloudFolderName")
        }
        
        // Call this as soon as possible in your launch sequence.
        // Version 0.18.6 of the server is the first with error handling for gone and changed files/checkSums.
        SyncServer.session.appLaunchSetup(withServerURL: serverURL, cloudFolderName:cloudFolderName, minimumServerVersion: ServerVersion(rawValue: "0.18.6"), failoverMessageURL: failoverURL)
    
        // Used by SMEmail in messages where email isn't allowed.
        SMUIMessages.session().appName = "Shared Images"

        let coreDataSession = CoreData(options: [
            CoreDataBundleModelName: "SharedImages",
            CoreDataSqlliteBackupFileName: "~SharedImages.sqlite",
            CoreDataSqlliteFileName: "SharedImages.sqlite",
            CoreDataLightWeightMigration: true
        ]);
        
        CoreData.registerSession(coreDataSession, forName: CoreDataExtras.sessionName)
        
        tabBarController = (UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "TabBarController") as! UITabBarController)
        tabBarController.delegate = tabBarDelegate
        window = UIWindow(frame: UIScreen.main.bounds)
        window!.rootViewController = tabBarController
        
        // Putting this after setting up the `tabBarController` because it can lead to access to the tabBarController.
        SetupSignIn.session.appLaunch(options: launchOptions)
        
        // The default UI displayed tab is .signIn
        if SignInManager.session.userIsSignedIn {
            // User is signed in. We're by-passing the SignInVC screen. We need a delegate for SharingInvitation to accept sharing invitations in this case.
            sharingDelegate = SharingInviteDelegate()
            SharingInvitation.session.delegate = sharingDelegate

            selectTabInController(tab: .images)
        }
        
        let imageUUIDs = Image.fetchAll().map { $0.uuid!}
        let discussionUUIDs = Discussion.fetchAll().map { $0.uuid!}
        do {
            if let results = try SyncServer.session.localConsistencyCheck(clientFiles: imageUUIDs + discussionUUIDs) {
                let missing = Array(results.clientMissingAndDeleted)
                // Somehow these were deleted in the SyncServer meta data, but not deleted from the Shared Images client. Delete them now.
                ImageExtras.removeLocalImages(uuids: missing)
            }
        } catch (let error) {
            Log.error("Error doing local consistency check: \(error)")
        }
        
        // 2/18/19; [3] Until I get issues with background fetching resolved.
        // let minimumBackgroundFetchIntervalOneHour:TimeInterval = 60 * 60
        // application.setMinimumBackgroundFetchInterval(minimumBackgroundFetchIntervalOneHour)

        Fabric.with([Crashlytics.self])
        
        Progress.session.stop = {
            SyncServer.session.stopSync()
        }
        
        UnreadCountBadge.update()
        Migrations.session.launch()
        ImagesHandler.setup()
        
        // For [2] below.
        UNUserNotificationCenter.current().delegate = self
        
        return true
    }
    
    // The specific values for this enum correspond to the order of the tabs, left to right, in the UI.
    enum Tab : Int {
        case signIn = 0
        case images = 1
        case settings = 2
    }
    
    func selectTabInController(tab:Tab) {
        tabBarController.selectedIndex = tab.rawValue
    }
    
    func tabInController(tab:Tab) -> UITabBarItem {
        return tabBarController.tabBar.items![tab.rawValue]
    }
    
    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
        return SignInManager.session.application(app, open: url, options: options) ||
        SharingInvitation.session.application(app, open: url, options: options)
    }
    
    func application(_ application: UIApplication, handleEventsForBackgroundURLSession identifier: String, completionHandler: @escaping () -> Void) {
        SyncServer.session.application(application, handleEventsForBackgroundURLSession: identifier, completionHandler: completionHandler)
    }

    // I've had been having issues with getting this to work. For troubleshooting, see https://stackoverflow.com/questions/39197933/how-to-troubleshoot-ios-background-app-fetch-not-working
    // https://developer.apple.com/documentation/uikit/uiapplicationdelegate/1623125-application
    // The "final" fix was to run a `beginBackgroundTask`. See the above SO link.
    // 2/27/19; Commented this out, along with [3] above-- don't want background fetch until I get some issues resolved.
#if false
    func application(_ application: UIApplication, performFetchWithCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
    
        var bgTaskId:UIBackgroundTaskIdentifier!
        
        func endBgTask() {
            application.endBackgroundTask(bgTaskId)
            bgTaskId = UIBackgroundTaskIdentifier.invalid
        }
        
        bgTaskId = application.beginBackgroundTask() {
            endBgTask()
        }
    
        AppBadge.session.setBadge() { (fetchResult:UIBackgroundFetchResult) in
            completionHandler(fetchResult)
            endBgTask()
        }
    }
#endif
    
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        Notifications.session.application(application, didRegisterForRemoteNotificationsWithDeviceToken: deviceToken)
    }
    
    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        Notifications.session.application(application, didFailToRegisterForRemoteNotificationsWithError: error)
    }
    
    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable : Any]) {
        // Not needed or called given [2].
        // Notifications.session.application(application, didReceiveRemoteNotification: userInfo)
    }

    func applicationWillResignActive(_ application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and invalidate graphics rendering callbacks. Games should use this method to pause the game.
        
        // 12/29/18; I think this was the cause of https://github.com/crspybits/SharedImages/issues/139 Instead, I'm going to now periodically make the Index endpoint call to make sure the Albums screen is up to date. See [1] in SyncController.
        // AppBadge.session.setBadge()
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        ImagesHandler.session.appDidEnterBackground()
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        ImagesHandler.session.appWillEnterForeground()
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    }

    func applicationWillTerminate(_ application: UIApplication) {
        CoreData.sessionNamed(CoreDataExtras.sessionName).saveContext()
    }
}

extension AppDelegate: UNUserNotificationCenterDelegate {
    // [2]. This method will be called when app received push notifications in foreground
    // See also https://stackoverflow.com/questions/14872088/get-push-notification-while-app-in-foreground-ios
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.alert, .badge, .sound])
    }
}

#if DEBUG
extension UIWindow {
    override open func motionBegan(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
        if motion == .motionShake {
            if let rootVC = UIApplication.shared.keyWindow?.rootViewController {
                RosterDevVC.show(fromViewController: rootVC, rowContents:DebugDashboardData.session.sections(), options: .all)
            }
        }
    }
}
#endif

