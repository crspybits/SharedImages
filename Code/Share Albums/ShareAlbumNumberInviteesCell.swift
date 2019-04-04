//
//  ShareAlbumNumberInviteesCell.swift
//  SharedImages
//
//  Created by Christopher G Prince on 4/3/19.
//  Copyright © 2019 Spastic Muffin, LLC. All rights reserved.
//

import UIKit
import SyncServer_Shared

class ShareAlbumNumberInviteesCell: UITableViewCell {
    @IBOutlet weak var slider: UISlider!
    @IBOutlet weak var numberInvitees: UILabel!
    
    var currSliderValue:UInt {
        return UInt(slider.value *
            Float(ServerConstants.maxNumberSharingInvitationAcceptors-1)) + 1
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    @IBAction func sliderAction(_ sender: Any) {
        numberInvitees.text = "\(currSliderValue)"
    }
}
