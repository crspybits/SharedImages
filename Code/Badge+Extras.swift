//
//  Badge+Extras.swift
//  SharedImages
//
//  Created by Christopher G Prince on 9/30/18.
//  Copyright © 2018 Spastic Muffin, LLC. All rights reserved.
//

import Foundation
import BadgeSwift

extension BadgeSwift {
    func format(withUnreadCount unreadCount: Int) {
        textColor = .white
        text = "\(unreadCount)"
        let padding:CGFloat = 3
        frame.origin = CGPoint(x: padding, y: padding)
        sizeToFit()
    }
}
