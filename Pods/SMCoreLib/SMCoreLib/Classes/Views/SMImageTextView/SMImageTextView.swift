//
//  SMImageTextView.swift
//  SMCoreLib
//
//  Created by Christopher Prince on 5/21/16.
//  Copyright © 2016 Spastic Muffin, LLC. All rights reserved.
//

// A text view with images. Deals with keyboard appearing and disappearing by changing the .bottom property of the .contentInset.

import Foundation
import HPTextViewTapGestureRecognizer

@objc public protocol SMImageTextViewDelegate : class {
    @objc optional func smImageTextView(_ imageTextView:SMImageTextView, imageWasDeleted imageId:Foundation.UUID?)
    
    // You should provide the UIImage corresponding to the NSUUID. Only in an error should this return nil.
    func smImageTextView(_ imageTextView: SMImageTextView, imageForUUID: Foundation.UUID) -> UIImage?
    
    @objc optional func smImageTextView(_ imageTextView: SMImageTextView, imageWasTapped imageId:Foundation.UUID?)
}

private class ImageTextAttachment : NSTextAttachment {
    var imageId:Foundation.UUID?
}

public func ==(lhs:SMImageTextView.ImageTextViewElement, rhs:SMImageTextView.ImageTextViewElement) -> Bool {
    return lhs.equals(rhs)
}

public func ===(lhs:SMImageTextView.ImageTextViewElement, rhs:SMImageTextView.ImageTextViewElement) -> Bool {
    return lhs.equalsWithRange(rhs)
}

open class SMImageTextView : UITextView, UITextViewDelegate {
    open weak var imageDelegate:SMImageTextViewDelegate?
    open var scalingFactor:CGFloat = 0.5
    
    override open var delegate: UITextViewDelegate? {
        set {
            if newValue == nil {
                super.delegate = nil
                return
            }
            
            Assert.badMojo(alwaysPrintThisString: "Delegate is setup by SMImageTextView, but you can subclass and declare-- all but shouldChangeTextInRange.")
        }
        
        get {
            return super.delegate
        }
    }
    
    override init(frame: CGRect, textContainer: NSTextContainer?) {
        super.init(frame: frame, textContainer: textContainer)
        self.setup()
    }
    
    required public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        self.setup()
    }
    
    fileprivate func setup() {
        super.delegate = self
        
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow), name: NSNotification.Name.UIKeyboardWillShow, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide), name: NSNotification.Name.UIKeyboardWillHide, object: nil)
        
        let tapGesture = HPTextViewTapGestureRecognizer()
        tapGesture.delegate = self
        self.addGestureRecognizer(tapGesture)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name.UIKeyboardWillShow, object: nil)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name.UIKeyboardWillHide, object: nil)
    }
    
    /*
    @objc private func imageTapGestureAction() {
        Log.msg("imageTapGestureAction")
    }*/
    
    fileprivate var originalEdgeInsets:UIEdgeInsets?
    
    // There are a number of ways to get the text view to play well the keyboard *and* autolayout: http://stackoverflow.com/questions/14140536/resizing-an-uitextview-when-the-keyboard-pops-up-with-auto-layout (see https://developer.apple.com/library/ios/documentation/StringsTextFonts/Conceptual/TextAndWebiPhoneOS/KeyboardManagement/KeyboardManagement.html for the idea of changing bottom .contentInset). I didn't use http://stackoverflow.com/questions/12924649/autolayout-constraint-keyboard, but it seems to be another means.
    @objc fileprivate func keyboardWillShow(_ notification:Notification) {
        let info = notification.userInfo!
        let kbFrame = info[UIKeyboardFrameEndUserInfoKey] as! NSValue
        let keyboardFrame = kbFrame.cgRectValue
        Log.msg("keyboardFrame: \(keyboardFrame)")
        
        self.originalEdgeInsets = self.contentInset
        var insets = self.contentInset
        insets.bottom += keyboardFrame.size.height
        self.contentInset = insets
    }

    @objc fileprivate func keyboardWillHide(_ notification:Notification) {
        self.contentInset = self.originalEdgeInsets!
    }
    
    open func insertImageAtCursorLocation(_ image:UIImage, imageId:Foundation.UUID?) {
        let attrStringWithImage = self.makeImageAttachment(image, imageId: imageId)
        self.textStorage.insert(attrStringWithImage, at: self.selectedRange.location)
    }
    
    fileprivate func makeImageAttachment(_ image:UIImage, imageId:Foundation.UUID?) -> NSAttributedString {
        // Modified from http://stackoverflow.com/questions/24010035/how-to-add-image-and-text-in-uitextview-in-ios

        let textAttachment = ImageTextAttachment()
        textAttachment.imageId = imageId
        
        let oldWidth = image.size.width
        
        //I'm subtracting 10px to make the image display nicely, accounting
        //for the padding inside the textView
        let scaleFactor = oldWidth / (self.frameWidth - 10)
        textAttachment.image = UIImage(cgImage: image.cgImage!, scale: scaleFactor/self.scalingFactor, orientation: image.imageOrientation)
        
        let attrStringWithImage = NSAttributedString(attachment: textAttachment)
        
        return attrStringWithImage
    }
    
    fileprivate static let ElementType = "ElementType"
    fileprivate static let ElementTypeText = "Text"
    fileprivate static let ElementTypeImage = "Image"
    fileprivate static let RangeLocation = "RangeLocation"
    fileprivate static let RangeLength = "RangeLength"
    fileprivate static let Contents = "Contents"

    public enum ImageTextViewElement : Equatable {
        case Text(String, NSRange)
        case image(UIImage?, Foundation.UUID?, NSRange)
        
        public var text:String? {
            switch self {
            case .Text(let string, _):
                return string
                
            case .image:
                return nil
            }
        }
        
        // Doesn't test range. For text, tests string. For image, tests uuid.
        public func equals(_ other:SMImageTextView.ImageTextViewElement) -> Bool {
            switch self {
            case .Text(let string, _):
                switch other {
                case .Text(let stringOther, _):
                    return string == stringOther
                case .image:
                    return false
                }
            
            case .image(_, let uuid, _):
                switch other {
                case .image(_, let uuidOther, _):
                    return uuid == uuidOther
                case .Text:
                    return false
                }
            }
        }
        
        public func equalsWithRange(_ other:SMImageTextView.ImageTextViewElement) -> Bool {
            switch self {
            case .Text(let string, let range):
                switch other {
                case .Text(let stringOther, let rangeOther):
                    return string == stringOther && range.length == rangeOther.length && range.location == rangeOther.location
                case .image:
                    return false
                }
            
            case .image(_, let uuid, let range):
                switch other {
                case .image(_, let uuidOther, let rangeOther):
                    return uuid == uuidOther && range.length == rangeOther.length && range.location == rangeOther.location
                case .Text:
                    return false
                }
            }
        }
        
        public func toDictionary() -> [String:AnyObject] {
            switch self {
            case .Text(let string, let range):
                return [ElementType: ElementTypeText as AnyObject, RangeLocation: range.location as AnyObject, RangeLength: range.length as AnyObject, Contents: string as AnyObject]
            
            case .image(_, let uuid, let range):
                var uuidString = ""
                if uuid != nil {
                    uuidString = uuid!.uuidString
                }                
                return [ElementType: ElementTypeImage as AnyObject, RangeLocation: range.location as AnyObject, RangeLength: range.length as AnyObject, Contents: uuidString as AnyObject]
            }
        }
        
        // UIImages in .Image elements will be nil.
        public static func fromDictionary(_ dict:[String:AnyObject]) -> ImageTextViewElement? {
            guard let elementType = dict[ElementType] as? String else {
                Log.error("Couldn't get element type")
                return nil
            }
            
            switch elementType {
            case ElementTypeText:
                guard let rangeLocation = dict[RangeLocation] as? Int,
                    let rangeLength = dict[RangeLength] as? Int,
                    let contents = dict[Contents] as? String
                else {
                    return nil
                }
                
                return .Text(contents, NSMakeRange(rangeLocation, rangeLength))
                
            case ElementTypeImage:
                guard let rangeLocation = dict[RangeLocation] as? Int,
                    let rangeLength = dict[RangeLength] as? Int,
                    let uuidString = dict[Contents] as? String
                else {
                    return nil
                }
                
                return .image(nil, UUID(uuidString: uuidString), NSMakeRange(rangeLocation, rangeLength))
            
            default:
                return nil
            }
        }
    }
    
    open var contents:[ImageTextViewElement]? {
        get {
            var result = [ImageTextViewElement]()
            
            // See https://stackoverflow.com/questions/37370556/ranges-of-strings-from-nsattributedstring

            self.attributedText.enumerateAttributes(in: NSMakeRange(0, self.attributedText.length), options: NSAttributedString.EnumerationOptions(rawValue: 0)) { (dict, range, stop) in
                Log.msg("dict: \(dict); range: \(range)")
                
                // 9/10/17; I'm having an odd issue here with NSAttributedStringKey.attachment versus NSAttachmentAttributeName. I can't seem to use #available(iOS 11, *) to select between them.
                // See https://stackoverflow.com/questions/46145780/nsattributedstringkey-attachment-versus-nsattachmentattributename/46148528#46148528
#if SWIFT4
                let dictValue = dict[NSAttributedStringKey.attachment]
#else
                let dictValue = dict[NSAttachmentAttributeName]
#endif
                if dictValue == nil {
                    let string = (self.attributedText.string as NSString).substring(with: range)
                    Log.msg("string in range: \(range): \(string)")
                    result.append(.Text(string, range))
                }
                else {
                    let imageAttachment = dictValue as! ImageTextAttachment
                    Log.msg("image at range: \(range)")
                    result.append(.image(imageAttachment.image!, imageAttachment.imageId, range))
                }
            }
            
            Log.msg("overall string: \(self.attributedText.string)")
            
            // TODO: Need to sort each of the elements in the result array by range.location. Not sure if the enumerateAttributesInRange does this for us.
            
            if result.count > 0 {
                return result
            } else {
                return nil
            }
        } // end get
        
        // Any .Image elements must have non-nil images.
        set {
            let mutableAttrString = NSMutableAttributedString()
            
            let currFont = self.font
            
            if newValue != nil {
                for elem in newValue! {
                    switch elem {
                    case .Text(let string, let range):
                        let attrString = NSAttributedString(string: string)
                        mutableAttrString.insert(attrString, at: range.location)
                    
                    case .image(let image, let uuid, let range):
                        let attrImageString = self.makeImageAttachment(image!, imageId: uuid)
                        mutableAttrString.insert(attrImageString, at: range.location)
                    }
                }
            }
            
            self.attributedText = mutableAttrString
            
            // Without this, we reset back to a default font size after the insertAttributedString above.
            self.font = currFont
        }
    }
}

// MARK: UITextViewDelegate
extension SMImageTextView {
    // Modified from http://stackoverflow.com/questions/29571682/how-to-detect-deletion-of-image-in-uitextview
    
    public func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {

        // empty text means backspace
        if text.isEmpty {
                // 9/10/17; I'm having an odd issue here with NSAttributedStringKey.attachment versus NSAttachmentAttributeName. I can't seem to use #available(iOS 11, *) to select between them.
                // See // See https://stackoverflow.com/questions/46145780/nsattributedstringkey-attachment-versus-nsattachmentattributename/46148528#46148528
#if SWIFT4
                let key = NSAttributedStringKey.attachment
#else
                let key = NSAttachmentAttributeName
#endif
            
                textView.attributedText.enumerateAttribute(key, in: NSMakeRange(0, textView.attributedText.length), options: NSAttributedString.EnumerationOptions(rawValue: 0)) { (object, imageRange, stop) in
            
                if let textAttachment = object as? ImageTextAttachment {
                    if NSLocationInRange(imageRange.location, range) {
                        Log.msg("Deletion of image: \(String(describing: object)); range: \(range)")
                        self.imageDelegate?.smImageTextView?(self, imageWasDeleted: textAttachment.imageId)
                    }
                }
            }
        }

        return true
    }
}

extension SMImageTextView : HPTextViewTapGestureRecognizerDelegate {
    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer!, handleTapOn textAttachment: NSTextAttachment!, in characterRange: NSRange) {
        let attach = textAttachment as! ImageTextAttachment
        self.imageDelegate?.smImageTextView?(self, imageWasTapped: attach.imageId)
    }
}
