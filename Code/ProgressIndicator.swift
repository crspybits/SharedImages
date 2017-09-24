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

class ProgressIndicator {
    private let label = UILabel()
    private let alert:AlertController
    private let totalImagesToDownload:UInt
    
    init(totalImagesToDownload: UInt, withStopHandler stop: @escaping ()->()) {
        self.totalImagesToDownload = totalImagesToDownload
        label.translatesAutoresizingMaskIntoConstraints = false

        alert = AlertController(title: "Downloading Images", message: "Please wait...")
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
        alert.present()
    }
    
    func dismiss() {
        alert.dismiss(animated: true, completion: nil)
    }
    
    func updateProgress(withNumberDownloaded numberDownloaded:UInt) {
        label.text = "\(numberDownloaded) of \(totalImagesToDownload) images..."
        label.sizeToFit()
    }
}
