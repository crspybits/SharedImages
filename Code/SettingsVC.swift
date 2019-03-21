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
        // First, log tracking info-- to try to give as much info as possible about user's state.
        SyncServer.session.logAllTracking() {
            guard Logger.archivedFileURLs.count > 0 else {
                SMCoreLib.Alert.show(fromVC: self, withTitle: "Alert!", message: "No log file present in app!")
                return
            }
            
            guard let email = SMEmail(parentViewController: self) else {
                // SMEmail gives the user an alert about this.
                return
            }
            
            for fileURL in Logger.archivedFileURLs {
                guard let logFileData = try? Data(contentsOf: fileURL, options: NSData.ReadingOptions()) else {
                    return
                }
                
                let fileName = fileURL.lastPathComponent
                email.addAttachmentData(logFileData, mimeType: "text/plain", fileName: fileName)
            }
            
            let versionDetails = SMEmail.getVersionDetails(for: "Neebla")!
            email.setMessageBody(versionDetails, isHTML: false)
            email.setSubject("Question or comment for developer of Neebla")
            email.setToRecipients(["chris@SpasticMuffin.biz"])
            email.show()
        }
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
