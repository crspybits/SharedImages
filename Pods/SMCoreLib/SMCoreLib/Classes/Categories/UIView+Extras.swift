//
//  UIView+Extras.swift
//  Catsy
//
//  Created by Christopher Prince on 9/13/15.
//  Copyright © 2015 Spastic Muffin, LLC. All rights reserved.
//

import Foundation
import UIKit

extension UIView {
    // Come up with a CGSize to maximally scale sizeToScale within containingSize, keeping it's aspect ratio.
    // Only scales down. If sizeToScale is smaller already, returns nil in that case. i.e., you can use the original size.
    public class func sizeToScaleDown(_ sizeToScale:CGSize, containingSize:CGSize) -> CGSize? {
        
        // Case 1) sizeToScale already fits.
        if sizeToScale.height <= containingSize.height && sizeToScale.width <= containingSize.width {
            return nil
        }
        
        // Case 2) One or both of sizeToScale's dimensions is too large. We are maximally fitting, so first try the maximum scale factor.
        var scaleFactor:CGFloat = max(containingSize.width/sizeToScale.width, containingSize.height/sizeToScale.height)
        
        if sizeToScale.height*scaleFactor > containingSize.height ||  sizeToScale.width*scaleFactor > containingSize.width {
            scaleFactor = min(containingSize.width/sizeToScale.width, containingSize.height/sizeToScale.height)
        }
        
        return CGSize(width: sizeToScale.width*scaleFactor, height: sizeToScale.height*scaleFactor)
    }
}
