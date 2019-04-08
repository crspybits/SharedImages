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
    public static var GoogleIcon:UIImage {
        let bundle = Bundle(for: self)
        return UIImage(named: "GoogleIcon", in: bundle,compatibleWith: nil)!
    }
    
    public static var DropboxIcon:UIImage {
        let bundle = Bundle(for: self)
        return UIImage(named: "DropboxIcon", in: bundle,compatibleWith: nil)!
    }
}
