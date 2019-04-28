//
//  AcquireImages.swift
//  SharedImages
//
//  Created by Christopher G Prince on 2/21/19.
//  Copyright © 2019 Spastic Muffin, LLC. All rights reserved.
//

import Foundation
import UIKit
import NohanaImagePicker
import Photos
import SMCoreLib
import SDCAlertView

public protocol AcquireImagesDelegate : class {
    // Called imediately before each image is acquired to obtain a URL for an image. A file shouldn't already exist at this URL when this returns.
    func acquireImagesURLForNewImage(_ acquireImages:AcquireImages) -> URL

    // Called after all the images have been acquired.
    func acquireImages(_ acquireImages:AcquireImages, images: [(newImageURL: URL, mimeType:String)])
}

public class AcquireImages: NSObject {
    open weak var delegate:AcquireImagesDelegate!

    // This should be a value between 0 and 1, with larger values giving higher quality, but larger files.
    open var compressionQuality:CGFloat = 0.5
    
    private weak var parentViewController:UIViewController!
    
    public init(withParentViewController parentViewController:UIViewController) {
        self.parentViewController = parentViewController
    }
    
    enum ImageType {
        case camera
        case photoLibrary
    }
    
    func acquire(type: ImageType) {
        switch PHPhotoLibrary.authorizationStatus() {
        case .notDetermined:
            PHPhotoLibrary.requestAuthorization {[weak self] status in
                DispatchQueue.main.async {
                    switch status {
                    case .authorized:
                        self?.acquireAux(type: type)
                    default:
                        break
                    }
                }
            }
        case .restricted, .denied:
            break
        case .authorized:
            self.acquireAux(type: type)
        }
    }
    
    private func acquireAux(type: ImageType) {
        switch type {
        case .camera:
            let imagePicker = UIImagePickerController()
            imagePicker.sourceType = .camera
            imagePicker.allowsEditing = false
            imagePicker.delegate = self
            self.parentViewController.present(imagePicker, animated: true, completion: nil)
        case .photoLibrary:
            let picker = NohanaImagePickerController()
            picker.cellMainAction = .longPressShowLargeImage
            picker.maximumNumberOfSelection = 10
            picker.delegate = self
            self.parentViewController.present(picker, animated: true, completion: nil)
        }
    }
    
    private func writeImageToFile(image: UIImage) -> URL? {
        let newFileURL = self.delegate?.acquireImagesURLForNewImage(self)
        
        if let imageData = image.jpegData(compressionQuality: self.compressionQuality) {
            do {
                try imageData.write(to: newFileURL! as URL, options: .atomicWrite)
            } catch {
                Log.error("Error writing file: \(error)")
                return nil
            }
        }
        else {
            Log.error("Couldn't convert image to JPEG!")
            return nil
        }
        
        return newFileURL
    }
}

extension AcquireImages: NohanaImagePickerControllerDelegate {
    public func nohanaImagePickerDidCancel(_ picker: NohanaImagePickerController) {
        picker.dismiss(animated: true, completion: nil)
    }
    
    public func nohanaImagePicker(_ picker: NohanaImagePickerController, didFinishPickingPhotoKitAssets pickedAssets: [PHAsset]) {
        
        let imageManager = PHImageManager.default()
        
        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.isNetworkAccessAllowed = true
        options.resizeMode = .exact
        options.isSynchronous = true
        
        var result = [(newImageURL: URL, mimeType:String)]()
        
        for asset in pickedAssets {
            imageManager.requestImageData(for: asset, options: options) { data, type, orientation, dict in
                if let data = data, let image = UIImage(data: data),
                    let newFileURL = self.writeImageToFile(image: image) {
                    result += [(newFileURL, "image/jpeg")]
                }
            }
        }
        
        if result.count > 0 {
            delegate.acquireImages(self, images: result)
        }
        
        picker.dismiss(animated: true, completion: nil)
    }
}

extension AcquireImages : UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    public func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        guard let image = info[UIImagePickerController.InfoKey.originalImage] as? UIImage else {
            return
        }
        
        if let newFileURL = writeImageToFile(image: image) {
            self.delegate.acquireImages(self, images: [(newImageURL: newFileURL, mimeType:"image/jpeg")])
        }
        
        picker.dismiss(animated: true, completion: nil)
    }
    
    public func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        Log.info("imagePickerControllerDidCancel")
        picker.dismiss(animated: true, completion: nil)
    }
}
