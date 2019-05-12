//
//  RemoveMedia.swift
//  SharedImages
//
//  Created by Christopher G Prince on 8/16/17.
//  Copyright © 2017 Spastic Muffin, LLC. All rights reserved.
//

import Foundation
import UIKit
import SMCoreLib
import SyncServer
import SDCAlertView

class RemoveMedia {
    private let media: [FileMediaObject]!
    private weak var parentVC: UIViewController!
    private let syncController: SyncController!
    private let sharingGroup: SyncServer.SharingGroup!
    private var completion:(()->())?
    
    init(_ media: [FileMediaObject], syncController: SyncController, sharingGroup: SyncServer.SharingGroup, withParentVC parentVC: UIViewController) {
        self.media = media
        self.parentVC = parentVC
        self.syncController = syncController
        self.sharingGroup = sharingGroup
    }
    
    // completion is called on successful deletion, not on cancellation.
    func start(completion:(()->())? = nil) {
        self.completion = completion
        
        let description = MediaTypeExtras.namesFor(media: self.media)

        let alert = AlertController(title: "Delete selected \(description)?", message: nil, preferredStyle: .alert)
        alert.behaviors = [.dismissOnOutsideTap]
        alert.popoverPresentationController?.sourceView = parentVC.view

        alert.addAction(AlertAction(title: "Cancel", style: .normal) { _ in
        })
        
        alert.addAction(AlertAction(title: "Delete", style: .destructive) {[unowned self] _ in
            self.removeMedia()
        })
        
        parentVC.present(alert, animated: true, completion: nil)
    }
    
    private func removeMedia() {
        // The sync/remote remove must happen before the local remove-- or we lose the reference!
        
        // 11/26/17; I got an error here "fileAlreadyDeleted". https://github.com/crspybits/SharedImages/issues/56-- `syncController.remove` failed.
        if !syncController.remove(media: media, sharingGroupUUID: sharingGroup.sharingGroupUUID) {

            let message = "Media already deleted on server."
            
            SMCoreLib.Alert.show(withTitle: "Error", message: message)
            Log.error("Error: \(message)")
            
            // I'm not going to return here. Even if somehow the image was already deleted on the server, let's make sure it was deleted locally.
        }
        
        // 12/2/17, 12/25/17; This is tricky. See https://github.com/crspybits/SharedImages/issues/61 and https://stackoverflow.com/questions/47614583/delete-multiple-core-data-objects-issue-with-nsfetchedresultscontroller
        // I'm dealing with this below. See the reference to this SO issue below.
        for mediaObj in media {
            // This also removes associated file(s) -- e.g., discussion, preview image.
            do {
                try mediaObj.remove()
            }
            catch (let error) {
                Log.error("Could not remove media: \(error)")
            }
        }
        
        CoreData.sessionNamed(CoreDataExtras.sessionName).saveContext()
        completion?()
    }
}
