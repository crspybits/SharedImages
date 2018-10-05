//
//  File.swift
//  SharedImages
//
//  Created by Christopher G Prince on 10/4/18.
//  Copyright © 2018 Spastic Muffin, LLC. All rights reserved.
//

import Foundation
import ODRefreshControl

extension ODRefreshControl {
    static func create(scrollView: UIScrollView, nav: UINavigationController, target: Any, selector: Selector) -> ODRefreshControl? {
        // To manually refresh-- pull down on collection view.
        guard let refreshControl = ODRefreshControl(in: scrollView) else {
            return nil
        }
        
        // A bit of a hack because the refresh control was appearing too high
        refreshControl.yOffset = -(nav.navigationBar.frameHeight + UIApplication.shared.statusBarFrame.height)
        
        // I like the "tear drop" pull down, but don't want the activity indicator.
        refreshControl.activityIndicatorViewColor = UIColor.clear
        
        refreshControl.addTarget(target, action: selector, for: .valueChanged)
        
        return refreshControl
    }
}
