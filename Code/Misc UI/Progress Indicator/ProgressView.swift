//
//  ProgressView.swift
//  SharedImages
//
//  Created by Christopher G Prince on 2/16/18.
//  Copyright © 2018 Spastic Muffin, LLC. All rights reserved.
//

import Foundation
import UIKit
import SMCoreLib

class ProgressView : UIView, XibBasics {
    typealias ViewType = ProgressView
    @IBOutlet private weak var spinnerContainer: UIView!
    @IBOutlet private weak var progressIndicator: UIView!
    @IBOutlet private weak var progressIndicatorWidth: NSLayoutConstraint!
    private var originalHeight: CGFloat!
    @IBOutlet weak var stopButton: UIButton!
    @IBOutlet weak var hideButton: UIButton!
    @IBOutlet weak var contents: UIView!
    @IBOutlet weak var contentsHeight: NSLayoutConstraint!
    private let reducedHeight:CGFloat = 5
    private var swipeGesture: UISwipeGestureRecognizer!
    private var progressViewIsHidden:Bool?
    private var spinner:SyncSpinner!
    private var timeThatSpinnerStarts:CFTimeInterval!
    private var progress:Float = 0
    
    enum DisplayHeight {
        case reduced
        case full
    }
    private var displayHeight:DisplayHeight?
    
    private var displayButtons: Bool = true {
        didSet {
            hideButton.isHidden = !displayButtons
            stopButton.isHidden = !displayButtons
        }
    }
    
    var stopAction:(()->())?
    
    func setup() {
        let spinnerSize:CGFloat = 25
        spinner = SyncSpinner(frame: CGRect(x: 0, y: 0, width: spinnerSize, height: spinnerSize))
        let spinnerButton = UIButton()
        spinnerButton.backgroundColor = UIColor.clear
        spinnerButton.frame = CGRect(x: 0, y: 0, width: spinnerSize, height: spinnerSize)
        spinnerButton.addSubview(spinner)
        spinnerContainer.addSubview(spinnerButton)
        
        progressIndicator.backgroundColor = UIColor(red: 0.0, green: 205.0/255.0, blue: 255.0/255.0, alpha: 1.0)
        contents.backgroundColor = UIColor(white: 0.95, alpha: 1.0)
        progressIndicatorWidth.constant = 0
        
        originalHeight = frameHeight
        
        swipeGesture = UISwipeGestureRecognizer(target: self, action: #selector(swipeAction))
        swipeGesture.direction = [.down, .up]
        addGestureRecognizer(swipeGesture)
    }
    
    @objc private func swipeAction() {
        if let progressViewIsHidden = progressViewIsHidden {
            if progressViewIsHidden {
                displayHeight = .full
                show(withAnimation: true)
            }
            else {
                hide(.reducedHeight, withAnimation: true)
            }
        }
    }
    
    // This won't let you access the controls on the progress view because the super view isn't actually beneath the view.
    func showOn(navController: UINavigationController, withAnimation: Bool, completion:(()->())? = nil) {
        frameWidth = navController.navigationBar.frameWidth
        frame.origin.y = navController.navigationBar.frameHeight
        navController.navigationBar.addSubview(self)

        if withAnimation {
            frameHeight = 0
        }

        show(withAnimation: withAnimation, completion: completion)
    }
    
    func showOn(viewController: UIViewController, withAnimation: Bool, completion:(()->())? = nil) {
        frameWidth = viewController.view.frameWidth
        viewController.view.addSubview(self)
        progressIndicatorWidth.constant = CGFloat(progress)
        
        // 3/23/19; Started having difficulties placing the progress view under the nav bar when I added in the new side menu. So, using constraints below (see https://stackoverflow.com/questions/44966786/how-do-i-programmatically-add-a-view-right-under-the-navigation-bar).
        translatesAutoresizingMaskIntoConstraints = false
        if #available(iOS 11.0, *) {
            let guide = viewController.view.safeAreaLayoutGuide
            trailingAnchor.constraint(equalTo: guide.trailingAnchor).isActive = true
            leadingAnchor.constraint(equalTo: guide.leadingAnchor).isActive = true
            topAnchor.constraint(equalTo: guide.topAnchor).isActive = true
        } else {
            NSLayoutConstraint(item: self,
                               attribute: .top,
                               relatedBy: .equal,
                               toItem: viewController.view, attribute: .top,
                               multiplier: 1.0, constant: 0).isActive = true
            NSLayoutConstraint(item: self,
                               attribute: .leading,
                               relatedBy: .equal, toItem: viewController.view,
                               attribute: .leading,
                               multiplier: 1.0,
                               constant: 0).isActive = true
            NSLayoutConstraint(item: self, attribute: .trailing,
                               relatedBy: .equal,
                               toItem: viewController.view,
                               attribute: .trailing,
                               multiplier: 1.0,
                               constant: 0).isActive = true
        }
        
        heightAnchor.constraint(equalToConstant: frameHeight).isActive = true
        layoutIfNeeded()

        show(withAnimation: withAnimation, completion: completion)
    }
    
    private func stopSpinnerWithMinimimumDisplayTime(completion:(()->())? = nil) {
        guard let timeThatSpinnerStarts = timeThatSpinnerStarts else {
            return
        }
        
        // If we don't let the spinner show for a minimum amount of time, it looks odd.
        let minimumDuration:CFTimeInterval = 2
        let difference:CFTimeInterval = CFAbsoluteTimeGetCurrent() - timeThatSpinnerStarts
        if difference > minimumDuration {
            self.spinner.stop()
            completion?()
        }
        else {
            let waitingTime = minimumDuration - difference
            
            TimedCallback.withDuration(Float(waitingTime)) {
                self.spinner.stop()
                completion?()
            }
        }
    }
    
    private func show(withAnimation: Bool, completion:(()->())? = nil) {
        progressViewIsHidden = false
        
        if progress > 0 {
            progressIndicatorWidth.constant = frameWidth * CGFloat(progress)
        }
        
        contentsHeight.constant = 0
        
        // Avoiding animating any constraint changes we don't want animated.
        layoutIfNeeded()
        
        if withAnimation {
            contentsHeight.constant = originalHeight
            UIView.animate(withDuration: 0.3, animations: {
                self.displayButtons = true
                self.layoutIfNeeded()
            }, completion: { _ in
                completion?()
            })
        }
        else {
            switch displayHeight {
            case .none, .some(.full):
                contentsHeight.constant = originalHeight
                displayHeight = .full
                displayButtons = true
                
            case .some(.reduced):
                contentsHeight.constant = reducedHeight
            }
            
            completion?()
        }
        
        if !self.spinner.animating {
            timeThatSpinnerStarts = CFAbsoluteTimeGetCurrent()
        }
        
        switch displayHeight {
        case .none, .some(.full):
            // Start each time to deal with issue where when we switch back to a view controller after being on another we don't get spinner spinning.
            self.spinner.start()
            
        case .some(.reduced):
            break
        }
    }

    enum HideType {
        case dismiss
        case reducedHeight
    }
    
    func hide(_ hideType: HideType, withAnimation: Bool, completion: (()->())? = nil) {
        progressViewIsHidden = true

        func hideConstraint() {
            switch hideType {
            case .reducedHeight:
                contentsHeight.constant = reducedHeight
                
            case .dismiss:
                contentsHeight.constant = 0
            }
        }
        
        func hide() {
            displayButtons = false
            
            switch hideType {
            case .reducedHeight:
                displayHeight = .reduced
                
            case .dismiss:
                progress = 0
                displayHeight = nil
            }
        }
        
        if withAnimation {
            switch hideType {
            case .reducedHeight:
                spinner.stop()
                
                hideConstraint()
                UIView.animate(withDuration: 0.3, animations: {[unowned self] in
                    hide()
                    self.layoutIfNeeded()
                }, completion: { _ in
                    completion?()
                    self.removeFromSuperview()
                })
                
            case .dismiss:
                stopSpinnerWithMinimimumDisplayTime() {[unowned self] in
                    self.contentsHeight.constant = 0
                    UIView.animate(withDuration: 0.3, animations: {
                        self.displayButtons = false
                        self.layoutIfNeeded()
                    }, completion: { _ in
                        completion?()
                        hide()
                        self.removeFromSuperview()
                    })
                }
            }
        }
        else {
            stopSpinnerWithMinimimumDisplayTime() {
                hide()
                hideConstraint()
                self.removeFromSuperview()
                completion?()
            }
        }
    }
    
    // Animate, if set, from current progress to new progress. progress value must be between 0 and 1.
    func setProgress(_ progress: Float, withAnimation: Bool, completion: (()->())? = nil) {
        guard superview != nil else {
            return
        }
        
        guard progress >= 0 && progress <= 1 else {
            return
        }
        
        self.progress = progress
        progressIndicatorWidth.constant = frameWidth * CGFloat(progress)
        
        if withAnimation {
            UIView.animate(withDuration: 0.3, animations: {
                self.layoutIfNeeded()
            }, completion: { _ in
                completion?()
            })
        }
    }
    
    @IBAction func stopAction(_ sender: Any) {
        hide(.dismiss, withAnimation: true)
        stopAction?()
    }
    
    @IBAction func hideAction(_ sender: Any) {
        hide(.reducedHeight, withAnimation: true)
    }
    
    func test(p: Float) {
        if p < 1 {
            DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(200)) {[unowned self] in
                self.setProgress(p, withAnimation: true) {
                    self.test(p: p + 0.1)
                }
            }
        }
        else {
            setProgress(1.0, withAnimation: true) {[unowned self] in
                self.hide(.dismiss, withAnimation: true)
            }
        }
    }
}
