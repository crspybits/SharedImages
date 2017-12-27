//
//  SyncController.swift
//  SharedImages
//
//  Created by Christopher Prince on 3/12/17.
//  Copyright © 2017 Spastic Muffin, LLC. All rights reserved.
//

import Foundation
import SyncServer
import SMCoreLib

enum SyncControllerEvent {
    case syncStarted
    case syncDone
    case syncError
}

protocol SyncControllerDelegate : class {
    func addLocalImage(syncController:SyncController, url:SMRelativeLocalURL, uuid:String, mimeType:String, title:String?, creationDate: NSDate?)
    func completedAddingLocalImages()
    func removeLocalImages(syncController:SyncController, uuids:[String])
    func syncEvent(syncController:SyncController, event:SyncControllerEvent)
}

class SyncController {
    private var progressIndicator: ProgressIndicator!
    private var numberDownloads: UInt!
    private var numberDownloadedSoFar: UInt!
    
    init() {
        SyncServer.session.delegate = self
        SyncServer.session.eventsDesired = [EventDesired.syncStarted, EventDesired.syncDone, EventDesired.willStartDownloads]
    }
    
    weak var delegate:SyncControllerDelegate!
    
    func sync() {
        SyncServer.session.sync()
    }
    
    func add(image:Image) {
        // Make both the creation and update dates the same because we don't have multiple file versions yet.
        var attr = SyncAttributes(fileUUID:image.uuid!, mimeType:image.mimeType!, creationDate: image.creationDate! as Date, updateDate: image.creationDate! as Date)
        
        if image.title != nil {
            attr.appMetaData = "{\"\(ImageExtras.appMetaDataTitleKey)\": \"\(image.title!)\"}";
        }
    
        do {
            try SyncServer.session.uploadImmutable(localFile: image.url!, withAttributes: attr)
            SyncServer.session.sync()
        } catch (let error) {
            Log.error("An error occurred: \(error)")
        }
    }
    
    func remove(images:[Image]) -> Bool {
        let uuids = images.map({$0.uuid!})
        
        // 2017-11-27 02:51:29 +0000: An error occurred: fileAlreadyDeleted [remove(images:) in SyncController.swift, line 64]
        do {
            try SyncServer.session.delete(filesWithUUIDs: uuids)
        } catch (let error) {
            Log.error("An error occurred: \(error)")
            return false
        }
        
        SyncServer.session.sync()
        return true
    }
}

extension SyncController : SyncServerDelegate {
    func singleFileDownloadComplete(url:SMRelativeLocalURL, attr: SyncAttributes) {
        // The files we get back from the SyncServer are in a temporary location.
        let newImageURL = FileExtras().newURLForImage()
        do {
            try FileManager.default.moveItem(at: url as URL, to: newImageURL as URL)
        } catch (let error) {
            Log.error("An error occurred moving a file: \(error)")
        }
    
        var title:String?
    
        Log.msg("attr.appMetaData: \(String(describing: attr.appMetaData))")
    
        // If present, the appMetaData will be a JSON string
        if let jsonData = attr.appMetaData?.data(using: String.Encoding.utf8, allowLossyConversion: false) {
        
            if let appMetaDataJSON = try? JSONSerialization.jsonObject(with: jsonData, options: []) as! [String: AnyObject] {
                title = appMetaDataJSON[ImageExtras.appMetaDataTitleKey] as? String
            }
        }

        delegate.addLocalImage(syncController: self, url: newImageURL, uuid: attr.fileUUID, mimeType: attr.mimeType, title:title, creationDate:attr.creationDate as NSDate?)
        
        delegate.completedAddingLocalImages()
        updateDownloadProgress()
    }
    
    private func updateDownloadProgress(count:UInt = 1) {
        // 12/3/17; We can get here from a call to `shouldDoDeletions`-- when the app is just recovering -- doing deletions on a refresh without having actually done any server interaction. i.e., the client interface has just cached some deletions.
        if numberDownloadedSoFar != nil {
            numberDownloadedSoFar! += count
            progressIndicator?.updateProgress(withNumberDownloaded: numberDownloadedSoFar)
            if numberDownloadedSoFar! >= numberDownloads {
                progressIndicator?.dismiss()
            }
        }
    }

    func shouldDoDeletions(downloadDeletions:[SyncAttributes]) {
        let uuids = downloadDeletions.map({$0.fileUUID!})
        delegate.removeLocalImages(syncController: self, uuids: uuids)
        updateDownloadProgress(count: UInt(uuids.count))
    }
    
    func syncServerErrorOccurred(error:SyncServerError) {
        Log.error("Server error occurred: \(error)")
        
        switch error {
        case .noNetworkError:
            SMCoreLib.Alert.show(withTitle: "The network connection was lost!", message: "Please try again later.")
        default:
            break
        }
        
        delegate.syncEvent(syncController: self, event: .syncError)
    }

    func syncServerEventOccurred(event:SyncEvent) {
        Log.msg("Server event occurred: \(event)")
        
        switch event {
        case .syncStarted:
            delegate.syncEvent(syncController: self, event: .syncStarted)
        
        case .willStartDownloads(numberFileDownloads: let numberFileDownloads, numberDownloadDeletions: let numberDownloadDeletions):
            numberDownloads = numberFileDownloads + numberDownloadDeletions
            numberDownloadedSoFar = 0
            
            // In case there's already one. Seems unlikely, but willStartDownloads can be repeated if we get a master version update.
            progressIndicator?.dismiss()
            
            // TESTING
            // TimedCallback.withDuration(30, andCallback: {
            //     Network.session().debugNetworkOff = true
            // })
            // TESTING
            
            progressIndicator = ProgressIndicator(imagesToDownload: numberFileDownloads, imagesToDelete: numberDownloadDeletions, withStopHandler: {
                SyncServer.session.stopSync()
            })
            progressIndicator.show()
            
        case .syncDone:
            delegate.syncEvent(syncController: self, event: .syncDone)
        
        default:
            break
        }
    }
    
#if DEBUG
    public func syncServerSingleFileUploadCompleted(next: @escaping () -> ()) {
        next()
    }
#endif
}
