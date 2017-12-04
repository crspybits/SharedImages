//
//  UIView+Extras.swift
//  SyncServer
//
//  Created by Christopher G Prince on 7/31/17.
//  Copyright © 2017 Spastic Muffin, LLC. All rights reserved.
//

import Foundation
import UIKit

extension UIView {
    public static func createFromXib<T>() -> T? {
        let bundle = Bundle(for: SignInManager.self)
        guard let viewType = bundle.loadNibNamed(typeName(self), owner: self, options: nil)?[0] as? T else {
            assert(false)
            return nil
        }
        
        return viewType
    }
}
