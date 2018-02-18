//
//  XibBasics.swift
//  SharedImages
//
//  Created by Christopher G Prince on 2/16/18.
//  Copyright © 2018 Spastic Muffin, LLC. All rights reserved.
//

import Foundation
import UIKit
import SMCoreLib

protocol XibBasics {
    associatedtype ViewType
}

extension XibBasics {
    static func create() -> ViewType? {
        return create(usingNibName: typeName(self))
    }
    
    static func create(usingNibName nibName: String) -> ViewType? {
        guard let viewType = Bundle.main.loadNibNamed(nibName, owner: self, options: nil)?[0] as? ViewType else {
            Log.error("Error: Could not load view!")
            assert(false)
            return nil
        }
        
        let view = viewType as! UIView
        view.autoresizingMask = [.flexibleWidth]
        
        return viewType
    }
}
