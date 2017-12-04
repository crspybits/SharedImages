//
//  Alert.swift
//  SMCoreLib
//
//  Created by Christopher Prince on 7/20/17.
//

import Foundation

public class Alert {
    public static func show(fromVC: UIViewController? = nil, withTitle title:String? = nil, message:String? = nil, allowCancel cancel:Bool = false, okCompletion:(()->())? = nil) {
    
        var vcToUse: UIViewController! = fromVC
        if vcToUse == nil {
            let window:UIWindow = (UIApplication.shared.delegate?.window)!!
            vcToUse = window.rootViewController!
        }
        
        let alert = UIAlertController(title: title, message: message, preferredStyle: .actionSheet)
        alert.popoverPresentationController?.sourceView = vcToUse.view!
    
        alert.addAction(UIAlertAction(title: "OK", style: .default) { alert in
            okCompletion?()
        })
        
        if cancel {
            alert.addAction(UIAlertAction(title: "Cancel", style: .default) { alert in
            })
        }
        
        vcToUse.present(alert, animated: true, completion: nil)
    }
}
