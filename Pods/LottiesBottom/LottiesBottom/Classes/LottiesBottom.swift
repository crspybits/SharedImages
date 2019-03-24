//
//  LottiesBottom.swift
//  Example
//
//  Created by Christopher G Prince on 9/23/17.
//  Copyright © 2017 Spastic Muffin, LLC. All rights reserved.
//

import Foundation
import UIKit
import Lottie

public class LottiesBottom : UIView {
    private weak var scrollView: UIScrollView!
    private var animationView:LOTAnimationView!
    
    // In some cases, animation remnants get left on the screen. And that doesn't look so good.
    public var durationAfterLastScrollToClearAnimation: TimeInterval = 0.5
    
    private var timer:Timer!

    public var completionThreshold: Float = 1.0 {
        didSet {
            assert(completionThreshold > 0.0 && completionThreshold <= 1.0)
        }
    }
    
    // In order to disable this control if needed.
    public var animating = true
    
    private var shouldHide = false
    private let top:CGFloat = 100
    private var lastOffset:CGFloat?
    
    private enum Direction {
    case up
    case down
    case none
    }
    
    private var direction:Direction = .none
    private var animationFullSize: (()->())?
    private var animationToFullSizeFinished = false
    
    private weak var parent: UIView!
    private var size: CGSize!
    private var bottomYOffset: CGFloat!
    
    // Adds LottiesBottom as a subview of the scroll view parent at the bottom center of the parent view, and animates it as the user drags up from the bottom.
    // `parent` is used so that we can position LottiesBottom at a fixed place at the bottom of the scroll view. It's assumed that the bottom of the scroll view is the same as the bottom of parent.
    // `bottomYOffset` -- offset the vertical position beyond just the height of bottom of the parent and the height of the animation container.
    public init(useLottieJSONFileWithName name: String, withSize size: CGSize, scrollView: UIScrollView, scrollViewParent parent: UIView, bottomYOffset:CGFloat = 0, animationFullSize: (()->())? = nil) {
        
        self.size = size
        self.scrollView = scrollView
        self.animationFullSize = animationFullSize
        self.parent = parent
        self.bottomYOffset = bottomYOffset
        
        animationView = LOTAnimationView(name: name)
        var myFrame = CGRect.zero
        myFrame.size = size
        animationView.frame = myFrame
        animationView.contentMode = .scaleAspectFill
        
        super.init(frame: myFrame)
        
        // So this animation is transparent to touches
        isUserInteractionEnabled = false
        
        addSubview(animationView)
        setNeedsLayout()
        
        scrollView.addObserver(self, forKeyPath: "contentOffset", options: [.new, .old], context: nil)
        
        parent.addSubview(self)
        setOrigin()
    }
    
    public required init?(coder aDecoder: NSCoder) {
        super.init(frame: CGRect.zero)
    }
    
    deinit {
        // 3/23/19; CGP; use scrollView as optional; get crash if scrollView deallocated first otherwise.
        scrollView?.removeObserver(self, forKeyPath: "contentOffset")
    }
    
    override public func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if animating {
            scrollViewDidScroll(scrollView)
        }
    }
    
    func setOrigin() {
        self.center.x = parent.center.x
        self.frame.origin.y = parent.frame.maxY - size.height + bottomYOffset
    }
    
    // Call this if the parent view controller did rotate.
    public func didRotate() {
        setOrigin()
    }
    
    private func scrollViewDidScroll(_ scrollView: UIScrollView) {
        timer?.invalidate()
        
        // 11/29/17; I'm using a few strategies to try to avoid scroll down from the top triggering  lotties bottom.
        
        // Strategy 1: Is the scroll location in the top 1/2 or the bottom half of the scroll view?
        let location = scrollView.panGestureRecognizer.location(in: scrollView)
        print("location: \(location)")
        if location.y < scrollView.frame.height/2 {
            return
        }
        
        let bottomEdge = scrollView.contentOffset.y + scrollView.frame.size.height;
        let offset = bottomEdge - scrollView.contentSize.height
        
        direction = .none
        
        // Strategies 2 and 3-- reset the last offset, and make sure the user is dragging.
        if let lastOffset = lastOffset, scrollView.isDragging {
            if offset > lastOffset {
                direction = .up
            }
            else if offset < lastOffset {
                direction = .down
            }
        }
        
        lastOffset = offset
        
        var position: CGFloat = 0
        if offset > 0 {
            position = min(1.0, offset/top)
        }
        
        print("offset: \(position)")
        let currProgress = animationView.animationProgress
        print("offset: \(position); progress: \(currProgress); direction: \(direction)")

        if currProgress >= CGFloat(completionThreshold) {
            if !animationToFullSizeFinished {
                animationFullSize?()
                animationToFullSizeFinished = true
            }
        }
        else {
            animationToFullSizeFinished = false
            
            // 5/22/18; Having problems with animation just staying on the screen, partially finished. Use a timer to make it disappear if user stops scrolling for a period of time.
            timer = Timer.scheduledTimer(timeInterval: durationAfterLastScrollToClearAnimation, target: self, selector: #selector(timerComplete), userInfo: nil, repeats: false)
        }
        
        if position > currProgress && direction == .up {
            if !animationView.isAnimationPlaying {
                // Need to play animation forward.
                animationView.play(fromProgress: currProgress, toProgress: position) {[unowned self] success in
                    if self.shouldHide {
                        // I'm getting a crash if I do this directly. Not sure if this helping though.
                        DispatchQueue.main.async {
                            self.hide()
                        }
                    }
                }
                print("Playing forward from \(currProgress) to \(position)")
            }
        } else if position < currProgress && direction == .down {
            if !animationView.isAnimationPlaying {
                // Need to play animation backward.
                animationView.play(fromProgress: currProgress, toProgress: position)
                print("Playing backward to \(position)")
            }
        }
    }
    
    @objc private func timerComplete() {
        animationToFullSizeFinished = true
        animationView.play(fromProgress: animationView.animationProgress, toProgress: 0)
        reset()
    }
    
    public func reset() {
        lastOffset = nil
    }
    
    public func hide() {
        if animating {
            if !animationView.isAnimationPlaying && animationView.animationProgress > 0 {
                shouldHide = false
                animationView.play(fromProgress: animationView.animationProgress, toProgress: 0, withCompletion: nil)
                print("Playing backward to 0 from: \(animationView.animationProgress)")
                reset()
            }
            else {
                shouldHide = true
            }
        }
        else {
            animationView.play(fromProgress: 0, toProgress: 0, withCompletion: nil)
        }
    }
}

