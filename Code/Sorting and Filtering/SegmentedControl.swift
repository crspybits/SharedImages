//
//  SegmentedControl.swift
//  SharedImages
//
//  Created by Christopher G Prince on 3/16/18.
//  Copyright © 2018 Spastic Muffin, LLC. All rights reserved.
//

import Foundation
import SMCoreLib

protocol SegmentedControlDelegate : class {
    func segmentedControlChanged(_ segmentedControl: SegmentedControl, selectionToIndex index: UInt)
}

class SegmentedControl: UIView {
    private var components:[SortControl]!
    weak var delegate:SegmentedControlDelegate!
    
    required init?(coder aDecoder: NSCoder) {
        super.init(frame: CGRect.zero)
    }
    
    private func makeSeparator() -> UIView {
        let separator = UIView()
        separator.frameWidth = 2.0
        separator.backgroundColor = .lightGray
        return separator
    }
    
    init(withComponents components: [SortControl]) {
        super.init(frame: CGRect.zero)
        self.components = components
        
        let height = components.reduce(into: 0) { (result, component) in
            result = max(result, component.frameHeight)
        }
        
        var currX:CGFloat = 0
        for (index, component) in components.enumerated() {
            if index > 0 {
                let separator = makeSeparator()
                separator.frameHeight = height
                separator.frameX = currX
                addSubview(separator)
                currX += separator.frameWidth
            }
            
            component.frameX = currX
            addSubview(component)
            currX += component.frameWidth
            
            component.delegate = self
        }
        
        frameHeight = height
        frameWidth = currX
        
        layer.borderColor = UIColor.gray.cgColor
        layer.borderWidth = 0.5
        layer.cornerRadius = 5.0
    }
    
    func select(componentIndex: UInt) {
        if componentIndex < 0 || componentIndex > self.components.count - 1 {
            return
        }
        
        for component in self.components {
            component.deselect()
        }
        
        self.components[Int(componentIndex)].select()
    }
}

extension SegmentedControl : SortControlDelegate {
    func sortControlSelected(_ sortControl: SortControl) {
        for (index, component) in self.components.enumerated() {
            if component == sortControl {
                delegate.segmentedControlChanged(self, selectionToIndex: UInt(index))
            }
            else {
                component.deselect()
            }
        }
    }
}
