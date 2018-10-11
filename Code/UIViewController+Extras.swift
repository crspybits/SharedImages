//
//  UIViewController+Extras.swift
//  SharedImages
//
//  Created by Christopher G Prince on 9/10/18.
//  Copyright © 2018 Spastic Muffin, LLC. All rights reserved.
//

import Foundation
import UIKit

extension UIViewController {
    // Adapted from https://stackoverflow.com/questions/41073915/swift-3-how-to-get-the-current-displaying-uiviewcontroller-not-in-appdelegate
    static func getTop() -> UIViewController? {

        var viewController:UIViewController?

        if let vc =  UIApplication.shared.delegate?.window??.rootViewController {

            viewController = vc
            var presented = vc

            while let top = presented.presentedViewController {
                presented = top
                viewController = top
            }
        }

        return viewController
    }
}
