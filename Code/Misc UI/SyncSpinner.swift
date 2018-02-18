//
//  SyncSpinner.swift
//  SharedNotes
//
//  Created by Christopher Prince on 4/27/16.
//  Copyright © 2016 Spastic Muffin, LLC. All rights reserved.
//

import Foundation
import UIKit
import SMCoreLib

class SyncSpinner : UIView {
    let normalImage = "SyncSpinner"
    let yellowImage = "SyncSpinnerYellow"
    let redImage = "SyncSpinnerRed"
    
    private var icon = UIImageView()
    private(set) var animating = false
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        self.setImage(usingBackgroundColor: .clear)
        self.icon.contentMode = .scaleAspectFit
        self.icon.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        var iconFrame = frame;
        iconFrame.origin = CGPoint.zero
        self.icon.frame = iconFrame
        self.addSubview(self.icon)
        self.stop()
    }
    
    enum BackgroundColor {
        case clear
        case yellow
        case red
    }
    
    private func setImage(usingBackgroundColor color:BackgroundColor) {
        var imageName:String
        switch color {
        case .clear:
            imageName = self.normalImage
            
        case .yellow:
            imageName = self.yellowImage
            
        case .red:
            imageName = self.redImage
        }
        
        let image = UIImage(named: imageName)
        self.icon.image = image
    }
    
    // Dealing with issue: Spinner started when view is not displayed. When view finally gets displayed, spinner graphic is displayed but it's not animating.
    override func layoutSubviews() {
        if self.animating {
            self.stop()
            self.start()
        }
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private let animationKey = "rotationAnimation"
    
    func start() {
        Log.msg("Started spinning...")
        self.setImage(usingBackgroundColor: .clear)
        self.animating = true
        self.isHidden = false
        let rotationAnimation = CABasicAnimation(keyPath: "transform.rotation.z")
        rotationAnimation.toValue = Double.pi * 2.0
        rotationAnimation.duration = 1
        rotationAnimation.isCumulative = true
        rotationAnimation.repeatCount = Float.infinity
        self.icon.layer.add(rotationAnimation, forKey: self.animationKey)
        
        // Dealing with issue of animation not restarting when app comes back from background.
        self.icon.layer.mb_setCurrentAnimationsPersistent()
    }
    
    func stop(withBackgroundColor color:BackgroundColor = .clear) {
        Log.msg("Stopped spinning...")

        self.animating = false
        
        self.setImage(usingBackgroundColor: color)

        // Make the spinner hidden when stopping iff background is clear
        self.isHidden = (color == .clear)
        
        self.icon.layer.removeAllAnimations()
    }
}
