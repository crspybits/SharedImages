//
//  ImagesTitle.swift
//  SharedImages
//
//  Created by Christopher G Prince on 3/22/19.
//  Copyright © 2019 Spastic Muffin, LLC. All rights reserved.
//

import UIKit

class ImagesTitle: UIView, XibBasics {
    typealias ViewType = ImagesTitle
    @IBOutlet weak var title: UILabel!
    var buttonAction:(()->())?
    @IBOutlet private weak var caretImage: UIImageView!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        caretImage.image = caretImage.image?.withRenderingMode(.alwaysTemplate)
    }
    
    @IBAction func buttonAction(_ sender: Any) {
        buttonAction?()
    }
    
    func updateCaret() {
        if Parameters.sortingOrderIsAscending {
            caretImage.transform = CGAffineTransform.identity.rotated(by: CGFloat(Double.pi))
        }
        else {
            caretImage.transform = CGAffineTransform.identity.rotated(by: 0)
        }
        
        if Parameters.filterApplied {
            caretImage.tintColor = .lightGray
        }
        else {
            caretImage.tintColor = nil
        }
    }
}
