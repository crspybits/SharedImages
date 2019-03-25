//
//  SideMenuItem.swift
//  SharedImages
//
//  Created by Christopher G Prince on 3/24/19.
//  Copyright © 2019 Spastic Muffin, LLC. All rights reserved.
//

import UIKit
import BadgeSwift

class SideMenuItem: UITableViewCell {
    @IBOutlet weak var icon: UIImageView!
    @IBOutlet weak var menuItem: UILabel!
    @IBOutlet weak var badgeContainer: UIView!
    private let badge = BadgeSwift()
    
    var badgeValue: Int? {
        didSet {
            badge.format(withUnreadCount: badgeValue)
            badge.isHidden = badgeValue == nil || badgeValue == 0
        }
    }

    override func awakeFromNib() {
        super.awakeFromNib()
        badgeContainer.addSubview(badge)
    }
}
