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
import M13ProgressSuite
import SMCoreLib

class Progress {
    static let session = Progress()
    private var totalNumber = 0
    private var numberCounted = 0
    private var totalStarts = 0
    
    // Set this to establish the nav controller on which the progress indicator is displayed. You can change this to a different nav controller if the user changes screens.
    weak var navController: UINavigationController! {
        didSet {
            oldValue?.cancelProgress()
            if let navController = navController {
                navController.showProgress()
                setProgress()
            }
        }
    }
    
    private init() {
    }

    func start(withTotalNumber totalNumber:Int) {
        self.totalNumber += totalNumber
        totalStarts += 1
        
        if let navController = navController {
            if !navController.isShowingProgressBar() {
                // Not quite sure why this is needed, but with out it, on the 2nd, 3rd time etc. the progress bar is displayed it first shows the entire width of the screen before shrinking back to where it should be.
                navController.setProgress(0, animated: false)
                
                navController.showProgress()
            }
            
            setProgress()
        }
    }
    
    private func setProgress() {
        guard totalNumber > 0 else {
            return
        }
        
        if let navController = navController {
            let progress = CGFloat(numberCounted)/CGFloat(totalNumber)
            Log.msg("setProgress: \(progress)")
            
            if progress > 0 {
                navController.setProgress(progress, animated: true)
            }
        }
    }
    
    func next(count: Int = 1) {
        guard totalNumber > 0 else {
            return
        }
        
        numberCounted += count
        
        setProgress()
        
        if numberCounted >= totalNumber {
            if let navController = navController {
                DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(500)) {
                    navController.finishProgress()
                }
            }
            
            numberCounted = 0
            totalNumber = 0
            totalStarts = 0
        }
    }
    
    func finish() {
        guard totalNumber > 0 else {
            return
        }
        
        totalStarts -= 1
        if totalStarts <= 0 {
            if let navController = navController {
                navController.finishProgress()
            }
            
            numberCounted = 0
            totalNumber = 0
            totalStarts = 0
        }
    }
}
