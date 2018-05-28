//
//  BottomRefresh.swift
//  SharedImages
//
//  Created by Christopher G Prince on 5/22/18.
//  Copyright © 2018 Spastic Muffin, LLC. All rights reserved.
//

import Foundation
import LottiesBottom

class BottomRefresh {
    private var bottomAnimation:LottiesBottom!
    
    var animating: Bool {
        get {
            return bottomAnimation.animating
        }
        
        set {
            bottomAnimation.animating = newValue
        }
    }
    
    init(withScrollView scrollView: UIScrollView, scrollViewParent: UIView, refreshAction: @escaping ()->()) {
        let size = CGSize(width: 200, height: 100)
        let animationLetters = ["C", "R", "D", "N"]
        let whichAnimation = Int(arc4random_uniform(UInt32(animationLetters.count)))
        let animationLetter = animationLetters[whichAnimation]
        
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        let tabBarHeight = appDelegate.tabBarController.tabBar.frame.size.height
        
        bottomAnimation = LottiesBottom(useLottieJSONFileWithName: animationLetter, withSize: size, scrollView: scrollView, scrollViewParent: scrollViewParent, bottomYOffset: -tabBarHeight) {[unowned self] in
            refreshAction()
            self.bottomAnimation.hide()
        }
        bottomAnimation.completionThreshold = 0.5
        
        // Getting an odd effect-- of LottiesBottom showing initially or if we have newer at bottom.
        bottomAnimation.animating = false
    }
    
    func didRotate() {
        bottomAnimation.didRotate()
    }
    
    func reset() {
        bottomAnimation.reset()
    }
    
    func hide() {
        self.bottomAnimation.hide()
    }
}
