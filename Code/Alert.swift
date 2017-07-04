//
//  Alert.swift
//  SharedImages
//
//  Created by Christopher Prince on 6/14/17.
//  Copyright © 2017 Spastic Muffin, LLC. All rights reserved.
//

import Foundation

class Alert {
    static func styleForIPad(_ alert:UIAlertController) {
        if alert.popoverPresentationController != nil {
            let color = UIColor(white: 0.80, alpha: 1.0)
            alert.popoverPresentationController!.backgroundColor = color
            alert.view.backgroundColor = color
        }
    }
}
