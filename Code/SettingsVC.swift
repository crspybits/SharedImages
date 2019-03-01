//
//  SettingsVC.swift
//  SharedImages
//
//  Created by Christopher G Prince on 8/19/17.
//  Copyright © 2017 Spastic Muffin, LLC. All rights reserved.
//

import Foundation
import UIKit
import SMCoreLib
import SyncServer

class SettingsVC : UIViewController {
    @IBOutlet weak var versionAndBuild: UILabel!
    
    var vb:String {
        if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
            let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String {
            return version + "/" + build
        }
        else {
            return ""
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        versionAndBuild.text = vb
        versionAndBuild.sizeToFit()
    }
    
    @IBAction func emailLogAction(_ sender: Any) {
        Log.msg("Log.logFileURL: \(Log.logFileURL!)")
        
        // First, log tracking info-- to try to give as much info as possible about user's state.
        SyncServer.session.logAllTracking() {
            guard let logFileData = try? Data(contentsOf: Log.logFileURL!, options: NSData.ReadingOptions()) else {
                SMCoreLib.Alert.show(fromVC: self, withTitle: "Alert!", message: "No log file present in app!")
                return
            }
            
            guard let email = SMEmail(parentViewController: self) else {
                // SMEmail gives the user an alert about this.
                return
            }
            
            email.addAttachmentData(logFileData, mimeType: "text/plain", fileName: Log.logFileName)

            let versionDetails = SMEmail.getVersionDetails(for: "Neebla")!
            email.setMessageBody(versionDetails, isHTML: false)
            email.setSubject("Log for developer of SharedImages")
            email.setToRecipients(["chris@SpasticMuffin.biz"])
            email.show()
        }
    }
    
    @IBAction func resetLogAction(_ sender: Any) {
        SMCoreLib.Alert.show(fromVC: self, withTitle: "Alert!", message: "Really reset log file?", allowCancel: true, okCompletion: {
            _ = Log.deleteLogFile()
        })
    }
    
    @IBAction func resetUnreadCountsAction(_ sender: Any) {
        SMCoreLib.Alert.show(fromVC: self, withTitle: "Alert!", message: "Really reset all discussion thread unread counts (across all albums)?", allowCancel: true, okCompletion: {
            let discussions = Discussion.fetchAll()
            discussions.forEach { discussion in
                discussion.unreadCount = 0
            }
            CoreData.sessionNamed(CoreDataExtras.sessionName).saveContext()
            UnreadCountBadge.update()
        })
    }
}
