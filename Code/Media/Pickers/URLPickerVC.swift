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
import NVActivityIndicatorView

protocol URLPickerDelegate: AnyObject {
    // Called when "Add" method on the picker is tapped.
    func urlPicker(_ picker: URLPickerVC, urlSelected: URLPickerVC.SelectedURL)
}

class URLPickerVC: UIViewController, NVActivityIndicatorViewable {
    struct SelectedURL {
        let data: LinkData
        let image: LinkPreview.LoadedImage?
    }
    
    @IBOutlet weak var searchBar: UISearchBar!
    @IBOutlet weak var linkPreviewContainer: UIView!
    @IBOutlet weak var marginView: UIView!
    @IBOutlet weak var acceptButton: UIButton!
    @IBOutlet weak var linkPreview: UIView!
    private weak var delegate: URLPickerDelegate!
    private var selectedURL: URLPickerVC.SelectedURL?
    
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
    
    static func show(fromParentVC parentVC: UIViewController, withDelegate delegate: URLPickerDelegate) {
        let vc = URLPickerVC.create()
        vc.delegate = delegate
        parentVC.customPresentViewController(vc.presenter, viewController: vc, animated: true, completion: nil)
    }
    
    @IBAction func cancelAction(_ sender: Any) {
        dismiss(animated: true, completion: nil)
    }
    
    @IBAction func acceptAction(_ sender: Any) {
        if let selectedURL = selectedURL {
            self.delegate.urlPicker(self, urlSelected: selectedURL)
            dismiss(animated: true, completion: nil)
        }
    }
    
    private func updateScheme(urlString: String) -> String? {
        guard let url = URL(string: urlString),
            let components = URLComponents(url: url, resolvingAgainstBaseURL: true) else {
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
        
        startAnimating()
        PreviewManager.session.getLinkData(url: url) { linkData in
            self.stopAnimating()
            if let linkData = linkData {
                self.linkPreview.removeAllSubviews()
                self.linkPreviewContainer.isHidden = false
                
                let preview = LinkPreview.create(with: linkData) {[weak self] image in
                    guard let self = self else {return}
                    self.selectedURL = URLPickerVC.SelectedURL(data: linkData, image: image)
                }
                
                self.linkPreview.addSubview(preview)
                preview.centerXAnchor.constraint(equalTo: self.linkPreview.centerXAnchor).isActive = true
                preview.centerYAnchor.constraint(equalTo: self.linkPreview.centerYAnchor).isActive = true
                preview.heightAnchor.constraint(equalToConstant: self.linkPreview.frameHeight).isActive = true
                preview.widthAnchor.constraint(equalToConstant: self.linkPreview.frameWidth).isActive = true
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
