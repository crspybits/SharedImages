//
//  ModalVC.swift
//  SharedImages
//
//  Created by Christopher G Prince on 2/3/18.
//  Copyright © Spastic Muffin, LLC. All rights reserved.
//

import Foundation
import UIKit

class ModalVC : UIViewController {
    private var changeFrameTd:ChangeFrameTransitioningDelegate!
    var parentVC: UIViewController!
    private var closeHandler:(()->())?
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        closeHandler?()
    }
    
    // `closeHandler` gets called when the ModalVC gets closed.
    func show(fromParentVC parentVC: UIViewController, usingNavigationController: Bool = true, closeHandler:(()->())? = nil) {
        self.parentVC = parentVC
        self.closeHandler = closeHandler
        
        var vcToPresent: UIViewController = self
        
        if usingNavigationController {
            let barButton = UIBarButtonItem(image: #imageLiteral(resourceName: "close"), style: .plain, target: self, action: #selector(close))
            
            navigationItem.rightBarButtonItem = barButton
            vcToPresent = UINavigationController(rootViewController: self)
        }
        
        changeFrameTd = ChangeFrameTransitioningDelegate(frame: view.frame)
        vcToPresent.modalPresentationStyle = .custom
        vcToPresent.transitioningDelegate = changeFrameTd
        vcToPresent.modalTransitionStyle = .coverVertical
        parentVC.present(vcToPresent, animated: true, completion: nil)
    }
    
    @objc func close() {
        changeFrameTd.close()
    }
}
