//
//  SMIcons.swift
//  SMCoreLib
//
//  Created by Christopher Prince on 6/13/16.
//  Copyright © 2016 Spastic Muffin, LLC. All rights reserved.
//

// Provide access to icons stored in the assets catalog of SMCoreLib

import Foundation

open class SMIcons {
    open static var GoogleIcon:UIImage {
        let bundle = Bundle(for: self)
        // Log.msg("bundle: \(bundle)")
        return UIImage(named: "GoogleIcon", in: bundle,compatibleWith: nil)!
    }
}
