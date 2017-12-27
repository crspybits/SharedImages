//
//  ProgressIndicator.swift
//  SharedImages
//
//  Created by Christopher G Prince on 9/14/17.
//  Copyright © 2017 Spastic Muffin, LLC. All rights reserved.
//

import Foundation
import UIKit
import SDCAlertView
import SMCoreLib

class ProgressIndicator {
    private let label = UILabel()
    private var alert:AlertController!
    private var totalImages:UInt!

    // So that the progress indicator shows up for at least a moment. Otherwise, for example-- with deleting files-- you can't tell what the app is doing.
    private var startTime:Double!
    let minDisplaySeconds = 2.0
    
    init(imagesToUpload:UInt, imagesToUploadDelete:UInt, withStopHandler stop: @escaping ()->()) {
        totalImages = imagesToUpload + imagesToUploadDelete
        
        var title = ""
        if imagesToUpload > 0 && imagesToUploadDelete > 0 {
            title = "Uploading & Upload Deleting Images"
        }
        else if imagesToUpload > 0 {
            title = "Uploading Image"
            if imagesToUpload > 1 {
                title += "s"
            }
        }
        else if imagesToUploadDelete > 0 {
            title = "Upload Deleting Image"
            if imagesToUploadDelete > 1 {
                title += "s"
            }
        }
        else {
            assert(false)
        }

        setup(withTitle: title, withStopHandler: stop)
    }
    
    init(imagesToDownload: UInt, imagesToDelete:UInt, withStopHandler stop: @escaping ()->()) {
        totalImages = imagesToDownload + imagesToDelete
        
        var title = ""
        if imagesToDownload > 0 && imagesToDelete > 0 {
            title = "Downloading & Deleting Images"
        }
        else if imagesToDownload > 0 {
            title = "Downloading Image"
            if imagesToDownload > 1 {
                title += "s"
            }
        }
        else if imagesToDelete > 0 {
            title = "Deleting Image"
            if imagesToDelete > 1 {
                title += "s"
            }
        }
        else {
            assert(false)
        }

        setup(withTitle: title, withStopHandler: stop)
    }
    
    private func setup(withTitle title: String, withStopHandler stop: @escaping ()->()) {
        label.translatesAutoresizingMaskIntoConstraints = false
        
        alert = AlertController(title: title, message: "Please wait...")
        alert.contentView.addSubview(label)

        label.centerXAnchor.constraint(equalTo: alert.contentView.centerXAnchor).isActive = true
        label.topAnchor.constraint(equalTo: alert.contentView.topAnchor).isActive = true
        label.bottomAnchor.constraint(equalTo: alert.contentView.bottomAnchor).isActive = true
        
        updateProgress(withNumberFilesProcessed: 0)

        alert.add(AlertAction(title: "Stop", style: .destructive) { alert in
            stop()
        })
    }
    
    func show() {
        // See https://stackoverflow.com/questions/358207/iphone-how-to-get-current-milliseconds
        startTime = CACurrentMediaTime()
        
        alert.present()
    }
    
    func dismiss() {
        // Make sure that we display the progress indicator for the minimum time.
        let endTime = CACurrentMediaTime()
        let diff = endTime - startTime
        if diff >= minDisplaySeconds {
            alert.dismiss(animated: true, completion: nil)
        }
        else {
            TimedCallback.withDuration(Float(minDisplaySeconds - diff)) {[unowned self] in
                self.alert.dismiss(animated: true, completion: nil)
            }
        }
    }
    
    func updateProgress(withNumberFilesProcessed numberProcessed:UInt) {
        label.text = "\(numberProcessed) of \(totalImages!) images..."
        label.sizeToFit()
    }
}
