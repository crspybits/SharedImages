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
import SDCAlertView

class RemoveImages {
    private let images: [ImageMediaObject]!
    private weak var parentVC: UIViewController!
    private let syncController: SyncController!
    private let sharingGroup: SyncServer.SharingGroup!
    private var completion:(()->())?
    
    init(_ images: [ImageMediaObject], syncController: SyncController, sharingGroup: SyncServer.SharingGroup, withParentVC parentVC: UIViewController) {
        self.images = images
        self.parentVC = parentVC
        self.syncController = syncController
        self.sharingGroup = sharingGroup
    }
    
    // completion is called on successful deletion, not on cancellation.
    func start(completion:(()->())? = nil) {
        self.completion = completion
        var imageTerm = "image"
        
        if images.count > 1 {
            imageTerm += "s"
        }
        
        let alert = AlertController(title: "Delete selected \(imageTerm)?", message: nil, preferredStyle: .alert)
        alert.behaviors = [.dismissOnOutsideTap]
        alert.popoverPresentationController?.sourceView = parentVC.view

        alert.addAction(AlertAction(title: "Cancel", style: .normal) { _ in
        })
        
        alert.addAction(AlertAction(title: "Delete", style: .destructive) {[unowned self] _ in
            self.removeImages()
        })
        
        parentVC.present(alert, animated: true, completion: nil)
        
#if false
        let alert = UIAlertController(title: "Delete selected \(imageTerm)?", message: nil, preferredStyle: .alert)
        alert.popoverPresentationController?.sourceView = parentVC.view

        alert.addAction(UIAlertAction(title: "Cancel", style: .default) { _ in
        })
        
        alert.addAction(UIAlertAction(title: "Delete", style: .destructive) {[unowned self] _ in
            self.removeImages()
        })
        
        parentVC.present(alert, animated: true, completion: nil)
#endif
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
        completion?()
    }
}
