//
//  RemoveImages.swift
//  SharedImages
//
//  Created by Christopher G Prince on 8/16/17.
//  Copyright © 2017 Spastic Muffin, LLC. All rights reserved.
//

import Foundation
import UIKit
import SMCoreLib
import SyncServer

class RemoveImages {
    private let images: [Image]!
    private weak var parentVC: UIViewController!
    private let syncController: SyncController!
    private let sharingGroup: SyncServer.SharingGroup!
    
    init(_ images: [Image], syncController: SyncController, sharingGroup: SyncServer.SharingGroup, withParentVC parentVC: UIViewController) {
        self.images = images
        self.parentVC = parentVC
        self.syncController = syncController
        self.sharingGroup = sharingGroup
    }
    
    func start() {
        var imageTerm = "image"
        
        if images.count > 1 {
            imageTerm += "s"
        }
        
        let alert = UIAlertController(title: "Delete selected \(imageTerm)?", message: nil, preferredStyle: .actionSheet)
        alert.popoverPresentationController?.sourceView = parentVC.view
    
        alert.addAction(UIAlertAction(title: "OK", style: .destructive) {[unowned self] _ in
            self.removeImages()
        })
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .default) { _ in
        })

        parentVC.present(alert, animated: true, completion: nil)
    }
    
    private func removeImages() {
        // The sync/remote remove must happen before the local remove-- or we lose the reference!
        
        // 11/26/17; I got an error here "fileAlreadyDeleted". https://github.com/crspybits/SharedImages/issues/56-- `syncController.remove` failed.
        if !syncController.remove(images: images, sharingGroupUUID: sharingGroup.sharingGroupUUID) {
            var message = "Image"
            if images.count > 1 {
                message += "s"
            }
            
            message += " already deleted on server."
            
            SMCoreLib.Alert.show(withTitle: "Error", message: message)
            Log.error("Error: \(message)")
            
            // I'm not going to return here. Even if somehow the image was already deleted on the server, let's make sure it was deleted locally.
        }
        
        // 12/2/17, 12/25/17; This is tricky. See https://github.com/crspybits/SharedImages/issues/61 and https://stackoverflow.com/questions/47614583/delete-multiple-core-data-objects-issue-with-nsfetchedresultscontroller
        // I'm dealing with this below. See the reference to this SO issue below.
        for image in images {
            // This also removes any associated discussion.
            do {
                try image.remove()
            }
            catch (let error) {
                Log.error("Could not remove image: \(error)")
            }
        }
        
        CoreData.sessionNamed(CoreDataExtras.sessionName).saveContext()
    }
}
