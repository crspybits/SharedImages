//
//  URLPickerVC.swift
//  SharedImages
//
//  Created by Christopher G Prince on 4/19/19.
//  Copyright © 2019 Spastic Muffin, LLC. All rights reserved.
//

import UIKit
import Presentr
import SMLinkPreview

class URLPickerVC: UIViewController {
    @IBOutlet weak var searchBar: UISearchBar!
    @IBOutlet weak var linkPreviewContainer: UIView!
    @IBOutlet weak var marginView: UIView!
    @IBOutlet weak var acceptButton: UIButton!
    @IBOutlet weak var linkPreview: UIView!
    
    private let presenter: Presentr = {
        let customPresenter = Presentr(presentationType: URLPickerVC.customType)
        customPresenter.transitionType = .coverVertical
        customPresenter.dismissTransitionType = .coverVertical
        customPresenter.roundCorners = false
        customPresenter.backgroundOpacity = 0.5
        customPresenter.dismissOnSwipe = true
        customPresenter.dismissOnSwipeDirection = .top
    
        return customPresenter
    }()
    
    private static let customType: PresentationType = {
        let height:Float = 500
        if UIDevice.current.userInterfaceIdiom == .pad {
            let customType = PresentationType.custom(width: .default, height: .custom(size: height), center: .center)
            return customType
        }
        else {
            let height = min(UIScreen.main.bounds.height, UIScreen.main.bounds.width)
            let customType = PresentationType.custom(width: .full, height: .custom(size: Float(height)), center: .center)
            return .fullScreen
        }
    }()
    
    static func create() -> URLPickerVC {
        let vc = URLPickerVC(nibName: "URLPickerVC", bundle: nil)
        return vc
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        searchBar.delegate = self
        searchBar.autocorrectionType = .no
        searchBar.autocapitalizationType = .none
        searchBar.placeholder = "Enter or paste website"
        
        linkPreviewContainer.isHidden = true
        
        marginView.layer.cornerRadius = 5
        marginView.clipsToBounds = true
    }
    
    static func show(fromParentVC parentVC: UIViewController) {
        let vc = URLPickerVC.create()
        parentVC.customPresentViewController(vc.presenter, viewController: vc, animated: true, completion: nil)
    }
    
    @IBAction func cancelAction(_ sender: Any) {
        dismiss(animated: true, completion: nil)
    }
    
    @IBAction func acceptAction(_ sender: Any) {
        dismiss(animated: true, completion: nil)
    }

    @IBAction func useHttpsSwitchAction(_ sender: Any) {
        processURL(searchBar: searchBar)
    }
    
    private func updateScheme(urlString: String) -> String? {
        guard let url = URL(string: urlString),
            var components = URLComponents(url: url, resolvingAgainstBaseURL: true) else {
            return nil
        }
    
        return components.url?.absoluteString
    }
    
    private func processURL(searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
        
        guard let text = searchBar.text?.trimmingCharacters(in: .whitespacesAndNewlines), text.count > 0 else {
            return
        }
        
        Log.debug("URL string: \(text)")
        
        guard let urlString = updateScheme(urlString: text) else {
            return
        }
        
        searchBar.text = urlString
        
        guard let url = URL(string: urlString) else {
            return
        }
        
        PreviewManager.session.getLinkData(url: url) { linkData in
            if let linkData = linkData {
                self.linkPreview.removeAllSubviews()
                self.linkPreviewContainer.isHidden = false
                
                let preview = LinkPreview.create(with: linkData)
                self.linkPreview.addSubview(preview)
                preview.centerXAnchor.constraint(equalTo: self.linkPreview.centerXAnchor).isActive = true
                preview.centerYAnchor.constraint(equalTo: self.linkPreview.centerYAnchor).isActive = true
                preview.heightAnchor.constraint(equalToConstant: self.linkPreview.frameHeight).isActive = true
                preview.widthAnchor.constraint(equalToConstant: self.linkPreview.frameWidth).isActive = true
                preview.size = self.linkPreview.frame.size
                preview.translatesAutoresizingMaskIntoConstraints = false
                
                self.view.layoutIfNeeded()
            }
        }
    }
}

extension URLPickerVC: UISearchBarDelegate {
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        processURL(searchBar: searchBar)
    }
    
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        if searchText.isEmpty {
            linkPreviewContainer.isHidden = true
        }
    }
}
