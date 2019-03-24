//
//  SideMenu.swift
//  SharedImages
//
//  Created by Christopher G Prince on 3/23/19.
//  Copyright © 2019 Spastic Muffin, LLC. All rights reserved.
//

import Foundation
import UIKit
import LGSideMenuController

class SideMenu: NSObject {
    static let session = SideMenu()
    let mainController:LGSideMenuController
    
    private let navController:UINavigationController
    private let hamburgerButton = UIButton(type: .system)
    private let leftMenuHamburgerButton:UIBarButtonItem
    private var transitioning: UIViewControllerAnimatedTransitioning!

    var rootViewController: UIViewController? {
        let vcs = navController.viewControllers
        if vcs.count > 0 {
            return vcs[0]
        }
        else {
            return nil
        }
    }
    
    private override init() {
        // Just a placeholder for first root VC.
        let rootVC = UIViewController()
        rootVC.view.backgroundColor = .white
        
        navController = UINavigationController(rootViewController: rootVC)
        
        let menuVC = LeftMenuVC.create()
        mainController = LGSideMenuController(rootViewController: navController, leftViewController: menuVC, rightViewController: nil)
        mainController.leftViewPresentationStyle = .slideBelow
        mainController.leftViewWidth = 300
        
        leftMenuHamburgerButton = UIBarButtonItem(customView: hamburgerButton)
        rootVC.navigationItem.leftBarButtonItem = leftMenuHamburgerButton
        
        super.init()

        hamburgerButton.addTarget(self, action: #selector(toggleLeftMenu), for: .touchUpInside)
        hamburgerButton.setImage(#imageLiteral(resourceName: "Hamburger"), for: .normal)
        hamburgerButton.sizeToFit()
    }
    
    @objc private func toggleLeftMenu() {
        mainController.toggleLeftViewAnimated()
    }
    
    func hideLeftMenu() {
        mainController.hideLeftViewAnimated()
    }
    
    // The root VC is the view controller showing on the screen when the menu is not displayed.
    func setRootViewController(_ newRootVC: UIViewController, animation: Bool = true) {
        newRootVC.navigationItem.leftBarButtonItem = leftMenuHamburgerButton
        if animation {
            leftAnimation(vc: newRootVC, completion: nil)
        }
        else {
            self.navController.setViewControllers([newRootVC], animated: false)
        }
    }
    
    private func leftAnimation(vc: UIViewController, completion: (()->())?) {
        mainController.hideLeftView(animated: true)
        transitioning = SlideLeftAnimation(animation: nil, completion: {[unowned self] in
            self.navController.setViewControllers([vc], animated: false)
            completion?()
            self.transitioning = nil
        })
    
        self.navController.delegate = self
        self.navController.pushViewController(vc, animated: true)
    }
}

private class SlideLeftAnimation: NSObject, UIViewControllerAnimatedTransitioning {
    private var animation: (()->())?
    private var completion: (()->())?
    
    init(animation: (()->())?, completion: (()->())?) {
        self.animation = animation
        self.completion = completion
    }
    
    func transitionDuration(using transitionContext: UIViewControllerContextTransitioning?) -> TimeInterval {
        return 0.3
    }
    
    func animateTransition(using transitionContext: UIViewControllerContextTransitioning) {
        let toViewController = transitionContext.viewController(forKey: UITransitionContextViewControllerKey.to)!
        let fromViewController = transitionContext.viewController(forKey: UITransitionContextViewControllerKey.from)!
        let finalFrameForToVC = transitionContext.finalFrame(for: toViewController)
        let initialFrameForFromVC = transitionContext.initialFrame(for: fromViewController)
        let containerView = transitionContext.containerView
        let bounds = UIScreen.main.bounds
        toViewController.view.frame = finalFrameForToVC.offsetBy(dx: bounds.size.width, dy: 0)
        containerView.addSubview(toViewController.view)
        
        UIView.animate(withDuration: transitionDuration(using: transitionContext), delay: 0.0, options: .curveEaseInOut, animations: {
            toViewController.view.frame = finalFrameForToVC
            fromViewController.view.frame = initialFrameForFromVC.offsetBy(dx: -bounds.size.width, dy: 0)
            self.animation?()
        }, completion: {_ in
            transitionContext.completeTransition(true)
            self.completion?()
        })
    }
}

extension SideMenu: UINavigationControllerDelegate {
    public func navigationController(_ navigationController: UINavigationController, animationControllerFor operation: UINavigationController.Operation, from fromVC: UIViewController, to toVC: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        return transitioning
    }
    
    func navigationController(_ navigationController: UINavigationController, willShow viewController: UIViewController, animated: Bool) {
    }
}
