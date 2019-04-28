//
//  SortControl.swift
//  SharedImages
//
//  Created by Christopher G Prince on 3/16/18.
//  Copyright © 2018 Spastic Muffin, LLC. All rights reserved.
//

import Foundation
import UIKit

protocol SortControlDelegate : class {
    func sortControlSelected(_ sortControl: SortControl)
}

class SortControl: UIView, XibBasics {
    typealias ViewType = SortControl

    enum ControlState {
        case ascending
        case descending
        
        func otherState() -> ControlState {
            return self == .ascending ? .descending : .ascending
        }
    }
    
    weak var delegate: SortControlDelegate?
    
    var currState:ControlState = .ascending {
        didSet {
            if oldValue == currState {
                return
            }
            
            UIView.animate(withDuration: 0.2) {
                switch self.currState {
                case .ascending:
                    self.icon.transform = CGAffineTransform(rotationAngle: CGFloat(2*Double.pi))

                case .descending:
                    self.icon.transform = CGAffineTransform(rotationAngle: CGFloat(-Double.pi))
                }
            }
        }
    }
    
    private var hiding: Bool = false
    
    func toggleState() {
        currState = currState.otherState()
    }
    
    // Return true iff this made the icon unhidden.
    @discardableResult
    func select() -> Bool {
        let prior = hiding
        alpha = 1.0
        hiding = false
        return prior != hiding
    }
    
    func deselect() {
        alpha = 0.25
        hiding = true
    }
    
    @IBOutlet weak var label: UILabel!
    @IBOutlet weak var stackView: UIStackView!
    @IBOutlet weak var icon: UIImageView!
    var buttonAction: (()->())?
    let padding:CGFloat = 10
    
    override func awakeFromNib() {
        super.awakeFromNib()
        currState = .ascending
        icon.image = #imageLiteral(resourceName: "up")
    }
        
    func setup(withName name: String) {
        label.text = name
    }
    
    @IBAction func buttonAction(_ sender: Any) {
        if !select() {
            // First tap is just to show the button if it's not already shown.
            toggleState()
            buttonAction?()
        }

        delegate?.sortControlSelected(self)
    }
}
