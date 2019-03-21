//
//  Progress.swift
//  SharedImages
//
//  Created by Christopher G Prince on 2/15/18.
//  Copyright © 2018 Spastic Muffin, LLC. All rights reserved.
//

// Keeping track of progress when you have an integer number of events or items that are going to occur.

import Foundation
import UIKit
import SMCoreLib

class Progress {
    static let session = Progress()
    private var totalNumber = 0
    private var numberCounted = 0
    private var totalStarts = 0
    private var progressView:ProgressView!
    
    // Set this to establish the view controller on which the progress indicator is displayed. You can change this to a different view controller if the user changes screens.
    weak var viewController: UIViewController! {
        didSet {
            if let viewController = viewController, totalNumber > 0 {
                progressView.showOn(viewController: viewController, withAnimation: false)
            }
            else {
                progressView.hide(.dismiss, withAnimation: false)
            }
        }
    }
    
    var stop:(()->())? {
        didSet {
            progressView.stopAction = stop
        }
    }
    
    private init() {
        progressView = ProgressView.create()
        progressView.setup()
    }

    func start(withTotalNumber totalNumber:Int) {
        if let viewController = viewController {
            progressView.showOn(viewController: viewController, withAnimation: self.totalNumber == 0)
        }
        
        self.totalNumber += totalNumber
        totalStarts += 1
    }
    
    private func setProgress(completion:(()->())? = nil) {
        guard totalNumber > 0 else {
            return
        }
        
        if let _ = viewController  {
            let progress = CGFloat(numberCounted)/CGFloat(totalNumber)
            Log.info("setProgress: \(progress)")
            
            if progress > 0 {
                progressView.setProgress(Float(progress), withAnimation: true, completion: completion)
            }
        }
    }
    
    func next(count: Int = 1) {
        guard totalNumber > 0 else {
            return
        }
        
        numberCounted += count
        
        setProgress() {[unowned self] in
            if self.numberCounted >= self.totalNumber {
                self.progressView.setProgress(1.0, withAnimation: true) {
                    self.progressView.hide(.dismiss, withAnimation: true)
                }
                
                self.numberCounted = 0
                self.totalNumber = 0
                self.totalStarts = 0
            }
        }
    }
    
    func finish() {
        guard totalNumber > 0 else {
            return
        }
        
        totalStarts -= 1
        if totalStarts <= 0 {
            if let _ = viewController  {
                progressView.setProgress(1.0, withAnimation: true) {[unowned self] in
                    self.progressView.hide(.dismiss, withAnimation: true)
                }
            }
            
            numberCounted = 0
            totalNumber = 0
            totalStarts = 0
        }
    }
}
