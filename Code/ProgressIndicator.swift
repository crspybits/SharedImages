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
    private let alert:AlertController
    private let totalImagesToDownload:UInt
    
    // So that the progress indicator shows up for at least a moment. Otherwise, for example-- with deleting files-- you can't tell what the app is doing.
    private var startTime:Double!
    let minDisplaySeconds = 2.0
    
    init(imagesToDownload: UInt, imagesToDelete:UInt, withStopHandler stop: @escaping ()->()) {
        self.totalImagesToDownload = imagesToDownload + imagesToDelete
        label.translatesAutoresizingMaskIntoConstraints = false
        
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

        alert = AlertController(title: title, message: "Please wait...")
        alert.contentView.addSubview(label)

        label.centerXAnchor.constraint(equalTo: alert.contentView.centerXAnchor).isActive = true
        label.topAnchor.constraint(equalTo: alert.contentView.topAnchor).isActive = true
        label.bottomAnchor.constraint(equalTo: alert.contentView.bottomAnchor).isActive = true
        
        updateProgress(withNumberDownloaded: 0)

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
    
    func updateProgress(withNumberDownloaded numberDownloaded:UInt) {
        label.text = "\(numberDownloaded) of \(totalImagesToDownload) images..."
        label.sizeToFit()
    }
}
