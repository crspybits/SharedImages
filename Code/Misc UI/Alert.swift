//
//  Alert.swift
//  SharedImages
//
//  Created by Christopher Prince on 6/14/17.
//  Copyright © 2017 Spastic Muffin, LLC. All rights reserved.
//

import Foundation
import UIKit
import SDCAlertView

class Alert {
    static func styleForIPad(_ alert:UIAlertController) {
        if alert.popoverPresentationController != nil {
            let color = UIColor(white: 0.80, alpha: 1.0)
            alert.popoverPresentationController!.backgroundColor = color
            alert.view.backgroundColor = color
        }
    }
    
    // For iPhone, this is .actionSheet. For iPad, this is .alert. Action sheets stand out on iPhone. On iPad, actionSheets are hard to see.
    static func prominentStyle() -> UIAlertController.Style {
        if UIDevice.current.userInterfaceIdiom == .pad {
            return .alert
        }
        else {
            return .actionSheet
        }
    }
}

extension AlertController {
    static func prominentStyle() -> AlertControllerStyle {
        if UIDevice.current.userInterfaceIdiom == .pad {
            return .alert
        }
        else {
            return .actionSheet
        }
    }
}
