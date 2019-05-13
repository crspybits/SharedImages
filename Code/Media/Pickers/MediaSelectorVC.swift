//
//  MediaSelectorVC.swift
//  SharedImages
//
//  Created by Christopher G Prince on 4/18/19.
//  Copyright © 2019 Spastic Muffin, LLC. All rights reserved.
//

import UIKit
import Presentr

class MediaSelectorVC: UIViewController {
    @IBOutlet weak var topLabel: UILabel!
    @IBOutlet weak var mainButtonContainer: UIStackView!
    @IBOutlet weak var cancel: UIButton!
    @IBOutlet weak var background: UIView!
    @IBOutlet weak var cameraButton: UIButton!
    private weak var parentVC: UIViewController!
    private weak var imageDelegate: AcquireImagesDelegate!
    private weak var urlPickerDelegate: URLPickerDelegate!
    private var acquireImages:AcquireImages!
    
    private let presenter: Presentr = {
        let customPresenter = Presentr(presentationType: MediaSelectorVC.customType)
        customPresenter.transitionType = .coverVertical
        customPresenter.dismissTransitionType = .coverVertical
        customPresenter.roundCorners = true
        customPresenter.backgroundOpacity = 0.5
        customPresenter.dismissOnSwipe = true
        customPresenter.dismissOnSwipeDirection = .top
    
        return customPresenter
    }()
    
    private static let customType: PresentationType = {
        if UIDevice.current.userInterfaceIdiom == .pad {
            let customType = PresentationType.custom(width: .half, height: .half, center: .bottomCenter)
            return customType
        }
        else {
            return .bottomHalf
        }
    }()
    
    static func create() -> MediaSelectorVC {
        let vc = MediaSelectorVC(nibName: "MediaSelectorVC", bundle: nil)
        return vc
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let cornerRadius = CGFloat(12)
        cancel.layer.cornerRadius = cornerRadius
        cancel.clipsToBounds = true
        background.layer.cornerRadius = cornerRadius
        background.clipsToBounds = true
        
        cameraButton.isHidden = !UIImagePickerController.isSourceTypeAvailable(
            UIImagePickerController.SourceType.camera)
    }
    
    static func show(fromParentVC parentVC: UIViewController,
        imageDelegate: AcquireImagesDelegate,
        urlPickerDelegate: URLPickerDelegate) -> MediaSelectorVC {
        let vc = MediaSelectorVC.create()
        vc.parentVC = parentVC
        vc.imageDelegate = imageDelegate
        vc.urlPickerDelegate = urlPickerDelegate
        parentVC.customPresentViewController(vc.presenter, viewController: vc, animated: true, completion: nil)
        return vc
    }
    
    @IBAction func urlAction(_ sender: Any) {
        dismiss(animated: true) {[weak self] in
            guard let self = self else {return}
            URLPickerVC.show(fromParentVC: self.parentVC, withDelegate: self.urlPickerDelegate)
        }
    }
    
    @IBAction func cameraAction(_ sender: Any) {
        dismiss(animated: true) { [unowned self] in
            self.acquireImages = AcquireImages(withParentViewController: self.parentVC)
            self.acquireImages.delegate = self.imageDelegate
            self.acquireImages.acquire(type: .camera)
        }
    }
    
    @IBAction func photoLibraryAction(_ sender: Any) {
        dismiss(animated: true) { [unowned self] in
            self.acquireImages = AcquireImages(withParentViewController: self.parentVC)
            self.acquireImages.delegate = self.imageDelegate
            self.acquireImages.acquire(type: .photoLibrary)
        }
    }
    
    @IBAction func cancelAction(_ sender: Any) {
        dismiss(animated: true, completion: nil)
    }
}
