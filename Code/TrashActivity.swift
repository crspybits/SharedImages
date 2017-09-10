//
//  TrashActivity.swift
//  SharedImages
//
//  Created by Christopher G Prince on 8/16/17.
//  Copyright © 2017 Spastic Muffin, LLC. All rights reserved.
//

import Foundation
import UIKit
import SMCoreLib

class TrashActivity : UIActivity {
    var images: [Image]!
    weak var parentVC: UIViewController!
    var removeImages:(([Image])->())!
    
    init(withParentVC parentVC: UIViewController, removeImages:@escaping ([Image])->()) {
        self.parentVC = parentVC
        self.removeImages = removeImages
    }
    
    // default returns nil. subclass may override to return custom activity type that is reported to completion handler
    override var activityType: UIActivityType? {
        return UIActivityType(rawValue: "\(type(of: self))")
    }

    // default returns nil. subclass must override and must return non-nil value
    override var activityTitle: String? {
        var title = "Delete\nImage"
        
        if images.count > 1 {
            title += "s"
        }
        
        return title
    }
    
    override var activityImage: UIImage? {
        return UIImage(named: "Deletion")
    }
    
    // The array will contain Image's and UIImage's-- filter out only the Image's
    // override this to return availability of activity based on items. default returns NO
    override func canPerform(withActivityItems activityItems: [Any]) -> Bool {
        let imageObjs = activityItems.filter({$0 is Image})
        guard imageObjs.count > 0, imageObjs is [Image] else {
            Log.error("No Image's given!")
            return false
        }

        images = imageObjs as! [Image]

        return true
    }
    
    override func perform() {
        super.perform()
        
        let alert = UIAlertController(title: "Delete selected images?", message: nil, preferredStyle: .actionSheet)
        alert.popoverPresentationController?.sourceView = parentVC.view
    
        alert.addAction(UIAlertAction(title: "OK", style: .destructive) { alert in
            self.removeImages(self.images)
            self.activityDidFinish(true)
        })
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .default) { alert in
            self.activityDidFinish(false)
        })

        parentVC.present(alert, animated: true, completion: nil)
    }
}
