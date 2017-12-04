//
//  SMAcquireImage.swift
//  SMCoreLib
//
//  Created by Christopher Prince on 5/22/16.
//  Copyright © 2016 Spastic Muffin, LLC. All rights reserved.
//

// Let a user acquire images from the camera or other sources.
// Note that this UI interacts with classes such as UITextView. E.g., it will cause the keyboard to be dismissed if present.

import Foundation
import UIKit

public protocol SMAcquireImageDelegate : class {
    // Called before the image is acquired to obtain a URL for the image. A file shouldn't exist at this URL yet.
    func smAcquireImageURLForNewImage(_ acquireImage:SMAcquireImage) -> SMRelativeLocalURL

    // Called after the image is acquired.
    func smAcquireImage(_ acquireImage:SMAcquireImage, newImageURL: SMRelativeLocalURL, mimeType:String)
}

open class SMAcquireImage : NSObject {
    open weak var delegate:SMAcquireImageDelegate!
    open var acquiringImage:Bool {
        return self._acquiringImage
    }
    
    // This should be a value between 0 and 1, with larger values giving higher quality, but larger files.
    open var compressionQuality:CGFloat = 0.5

    fileprivate weak var parentViewController:UIViewController!
    fileprivate let imagePicker = UIImagePickerController()
    open var _acquiringImage:Bool = false
    
    // documentsDirectoryPath is the path within the Documents directory to store new image files.
    public init(withParentViewController parentViewController:UIViewController) {
    
        super.init()
        self.parentViewController = parentViewController
        self.imagePicker.delegate = self
    }
    
    private enum ShowFromType {
    case barButton(UIBarButtonItem)
    case view(UIView)
    }
    
    private func showAlert(fromType type: ShowFromType) {
        self._acquiringImage = true
        
        let alert = UIAlertController(title: "Get an image?", message: nil, preferredStyle: .actionSheet)
        
        switch type {
        case .barButton(let barButton):
            alert.popoverPresentationController?.barButtonItem = barButton
        
        case .view(let view):
            alert.popoverPresentationController?.sourceView = view
        }
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { alert in
            self._acquiringImage = false
        })
        
        if UIImagePickerController.isSourceTypeAvailable(
                UIImagePickerControllerSourceType.camera) {
            alert.addAction(UIAlertAction(title: "Camera", style: .default) { alert in
                self.getImageUsing(.camera)
            })
        }

        if UIImagePickerController.isSourceTypeAvailable(.savedPhotosAlbum) {
            alert.addAction(UIAlertAction(title: "Camera Roll", style: .default) { alert in
                self.getImageUsing(.savedPhotosAlbum)
            })
        }

        if UIImagePickerController.isSourceTypeAvailable(.photoLibrary) {
            alert.addAction(UIAlertAction(title: "Photo Library", style: .default) { alert in
                self.getImageUsing(.photoLibrary)
            })
        }
        
        self.parentViewController.present(alert, animated: true, completion: nil)
    }
    
    open func showAlert(fromView view:UIView) {
        showAlert(fromType: .view(view))
    }

    open func showAlert(fromBarButton barButton:UIBarButtonItem) {
        showAlert(fromType: .barButton(barButton))
    }
    
    fileprivate func getImageUsing(_ sourceType:UIImagePickerControllerSourceType) {
        self.imagePicker.sourceType = sourceType
        self.imagePicker.allowsEditing = false

        self.parentViewController.present(imagePicker, animated: true,
            completion: nil)
    }
}

extension SMAcquireImage : UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    public func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : Any]) {
        Log.msg("info: \(info)")
        let image = info[UIImagePickerControllerOriginalImage] as! UIImage
        
        // Save image to album if you want; also considers video
        // http://www.techotopia.com/index.php/Accessing_the_iOS_8_Camera_and_Photo_Library_in_Swift
        
        let newFileURL = self.delegate?.smAcquireImageURLForNewImage(self)
        Log.msg("newFileURL: \(String(describing: newFileURL))")
        
        var success:Bool = true
        if let imageData = UIImageJPEGRepresentation(image, self.compressionQuality) {
            do {
                try imageData.write(to: newFileURL! as URL, options: .atomicWrite)
            } catch (let error) {
                Log.error("Error writing file: \(error)")
                success = false
            }
        }
        else {
            Log.error("Couldn't convert image to JPEG!")
            success = false
        }
        
        if success {
            self.delegate.smAcquireImage(self, newImageURL: newFileURL!, mimeType:"image/jpeg")
        }
        
        self._acquiringImage = false
        picker.dismiss(animated: true, completion: nil)
    }
    
    public func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        Log.msg("imagePickerControllerDidCancel")
        
        self._acquiringImage = false
        picker.dismiss(animated: true, completion: nil)
    }
}
