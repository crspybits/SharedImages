//
//  LinkPreview.swift
//  SMLinkPreview
//
//  Created by Christopher G Prince on 4/22/19.
//

import UIKit

public class LinkPreview: UIView {
    @IBOutlet weak var contentView: UIView!
    @IBOutlet weak var imageHeight: NSLayoutConstraint!
    @IBOutlet public weak var image: UIImageView!
    @IBOutlet weak var title: UILabel!
    @IBOutlet weak var url: UILabel!
    @IBOutlet weak var icon: UIImageView!
    @IBOutlet weak var iconContainerWidth: NSLayoutConstraint!
    @IBOutlet weak var textAndIconContainer: UIView!
    public var textAndIconAction:(()->())?
    private var haveImage: Bool = false
    private var doneSetup = false
    
    public enum LoadedImage {
        case large(UIImage)
        case icon(UIImage)
    }
    
    override public func awakeFromNib() {
        super.awakeFromNib()
    }
    
    // I was having problems getting the LinkPreview to load as an IBOutlet-- but this works: https://stackoverflow.com/questions/6906631/iboutlet-isnt-connected-in-awakefromnib
    override public func awakeAfter(using aDecoder: NSCoder) -> Any? {
        guard subviews.isEmpty else { return self }
        return LinkPreview.loadFromNib(anyClass: type(of: self), owner: nil)
    }
    
    public required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    private static func loadFromNib(anyClass: AnyClass, owner: Any?) -> Any? {
        let bundle = Bundle(for: anyClass)
        let nibName = String(describing: anyClass)
        return bundle.loadNibNamed(nibName, owner: owner, options: nil)?.first
    }
    
    public static func create(with linkData: LinkData, callback:((_ image: LoadedImage?)->())? = nil) -> LinkPreview {
        let preview = LinkPreview.loadFromNib(anyClass: self, owner: self) as! LinkPreview
        preview.setup(with: linkData, callback: callback)
        return preview
    }

    /// Call setup after calling this.
    public static func create() -> LinkPreview {
        return LinkPreview.loadFromNib(anyClass: self, owner: self) as! LinkPreview
    }
    
    /// The image is passed back in the form of a callback to allow for asynchronous image loading if needed.
    // Image data are loaded from the linkData icon/image URL's, if non-nil. Those URL's can refer to either local or remote files.
    public func setup(with linkData: LinkData, callback:((_ image: LoadedImage?)->())? = nil) {
        title.numberOfLines = Int(PreviewManager.session.config.maxNumberTitleLines)
        title.text = linkData.title
        url.text = linkData.url.urlWithoutScheme()

        var forceScheme:URL.ForceScheme?
        if PreviewManager.session.config.alwaysUseHTTPS {
            forceScheme = .https
        }
        
        var result:LoadedImage?
        
        if let imageURL = linkData.image,
            let data = try? Data(contentsOf: imageURL.attemptForceScheme(forceScheme)) {
            haveImage = true
            image.image = UIImage(data: data)
            if let image = image.image {
                result = .large(image)
            }
            applyCornerRounding(view: contentView)
            iconContainerWidth.constant = 0
            layoutIfNeeded()
            frame.size.height = textAndIconContainer.frame.height + image.frame.height
        }
        else {
            haveImage = false

            // No image; just have text area (title, URL) below.
            applyCornerRounding(view: textAndIconContainer)
            
            if let iconURL = linkData.icon {
                if let data = try? Data(contentsOf: iconURL.attemptForceScheme(forceScheme)) {
                    icon.image = UIImage(data: data)
                    if let icon = icon.image {
                        result = .icon(icon)
                    }
                }
            }
            else {
                iconContainerWidth.constant = 0
            }
            
            imageHeight.constant = 0
            layoutIfNeeded()
            frame.size.height = textAndIconContainer.frame.height
        }
        
        callback?(result)
    }

    override public func layoutSubviews() {
        super.layoutSubviews()
        
        if haveImage {
            imageHeight.constant =
                max(frame.size.height - textAndIconContainer.frame.height, 0)
        }
    }
    
    func applyCornerRounding(view: UIView) {
        view.layer.cornerRadius = 10
        view.clipsToBounds = true
        view.layer.borderColor = UIColor.lightGray.cgColor
        view.layer.borderWidth = 1
    }
    
    @IBAction func textAndIconAction(_ sender: Any) {
        textAndIconAction?()
    }
}
