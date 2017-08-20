//
//  SettingsVC.swift
//  SharedImages
//
//  Created by Christopher G Prince on 8/19/17.
//  Copyright © 2017 Spastic Muffin, LLC. All rights reserved.
//

import Foundation
import UIKit

class SettingsVC : UIViewController {
    @IBOutlet weak var imageOrderSwitch: UISwitch!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        imageOrderSwitch.isOn = ImageExtras.currentSortingOrder.stringValue == SortingOrder.newerAtTop.rawValue
    }
    
    @IBAction func imageOrderSwitchAction(_ imageOrderSwitch: UISwitch) {
        if imageOrderSwitch.isOn {
            ImageExtras.currentSortingOrder.stringValue = SortingOrder.newerAtTop.rawValue
        }
        else {
            ImageExtras.currentSortingOrder.stringValue = SortingOrder.newerAtBottom.rawValue
        }
    }
}
