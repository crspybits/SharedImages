//
//  DiscussionVC.swift
//  SharedImages
//
//  Created by Christopher G Prince on 1/30/18.
//  Copyright © 2018 Spastic Muffin, LLC. All rights reserved.
//

import UIKit
import MessageKit
import SMCoreLib
import SyncServer
import MessageInputBar

protocol DiscussionVCDelegate {
    func discussionVC(_ vc: DiscussionVC, resetUnreadCount:DiscussionFileObject)
    func discussionVC(_ vc: DiscussionVC, changedDiscussion:DiscussionFileObject)
    func discussionVC(_ vc: DiscussionVC, discussion:DiscussionFileObject, refreshWithCompletion: (()->())?)
    func discussionVCWillClose(_ vc: DiscussionVC)
}

class DiscussionVC: MessagesViewController {
    let maxMessageLength = 1024

    private var fixedObjectsURL: URL!
    private var fixedObjects:FixedObjects!
    var parentVC: UIViewController!
    private var closeHandler:(()->())?
    private var senderUserDisplayName:String!
    private var senderUserId:String!
    private var delegate:DiscussionVCDelegate!
    private var discussion: DiscussionFileObject!
    private var viewsLayedOut = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        navigationItem.title = "Discussion"
        
        messagesCollectionView.messagesDataSource = self
        messagesCollectionView.messagesLayoutDelegate = self
        messagesCollectionView.messagesDisplayDelegate = self
        messagesCollectionView.messageCellDelegate = self
        messageInputBar.delegate = self
        
        // 2/13/18; See https://github.com/crspybits/SharedImages/issues/81 and see https://github.com/MessageKit/MessageKit/issues/518
        messageInputBar.sendButton.titleLabel?.font = UIFont.systemFont(ofSize: 22.0)

        messageInputBar.sendButton.tintColor = UIColor(red: 69/255, green: 193/255, blue: 89/255, alpha: 1)
        scrollsToBottomOnKeyboardBeginsEditing = true // default false
        maintainPositionOnKeyboardFrameChanged = true // default false
        
        // So the view controller starts immediately below the nav bar
        edgesForExtendedLayout = []
    }
    
    @discardableResult
    private func loadDiscussion() -> Bool {
        guard let url = discussion.url else {
            SMCoreLib.Alert.show(fromVC: parentVC, withTitle: "Problem loading messages", message: "The discussion had no URL!")
            return false
        }
        
        self.fixedObjectsURL = url as URL
        fixedObjects = FixedObjects(withFile: fixedObjectsURL)
        
        guard fixedObjects != nil else {
            SMCoreLib.Alert.show(fromVC: parentVC, withTitle: "Problem loading messages", message: "Could not load from file!")
            return false
        }
        
        // Make sure that the file format containing the messages hasn't changed.
        for fixedObject in fixedObjects {
            guard let dict = fixedObject as? [String: String],
                let _ = DiscussionMessage.fromDictionary(dict) else {
                SMCoreLib.Alert.show(fromVC: parentVC, withTitle: "Problem loading messages", message: "Has there been a format change?")
                return false
            }
        }
        
        return true
    }
    
    // `closeHandler` gets called when the ModalVC gets closed.
    // Returns false iff the show failed.
    @discardableResult
    func show(fromParentVC parentVC: UIViewController, discussion: DiscussionFileObject, delegate:DiscussionVCDelegate, usingNavigationController: Bool = true, closeHandler:(()->())? = nil) -> Bool {
    
        self.parentVC = parentVC
        self.closeHandler = closeHandler
        self.delegate = delegate
        self.discussion = discussion
        
        guard loadDiscussion() else {
            return false
        }
        
        guard let username = SyncServerUser.session.creds?.username else {
            SMCoreLib.Alert.show(fromVC: parentVC, withTitle: "Alert!", message: "No user name for messages!")
            return false
        }
        
        senderUserDisplayName = username
        
        guard let userId = SyncServerUser.session.syncServerUserId else {
            SMCoreLib.Alert.show(fromVC: parentVC, withTitle: "Alert!", message: "No user id for messages!")
            return false
        }
        
        senderUserId = userId
        
        let closeBarButton = UIBarButtonItem(image: #imageLiteral(resourceName: "close"), style: .plain, target: self, action: #selector(close))
        navigationItem.leftBarButtonItem = closeBarButton
        
        let refreshBarButton = UIBarButtonItem(barButtonSystemItem: .refresh, target: self, action: #selector(refresh))
        navigationItem.rightBarButtonItem = refreshBarButton
        
        let nav = UINavigationController(rootViewController: self)
        
        // Otherwise, with edgesForExtendedLayout set to [], we'd get a gray nav bar
        nav.navigationBar.isTranslucent = false
        
        if UIDevice.current.userInterfaceIdiom == .pad {
            nav.modalTransitionStyle = .coverVertical
            nav.modalPresentationStyle = .formSheet
        }
        
        parentVC.present(nav, animated: true, completion: nil)
        
        discussion.unreadCount = 0
        discussion.save()

        // This is for iPad-- When you tap on the large image, it should reset the unread count then. Because otherwise, you can be looking at the discussion thread for that image, with the unread count badge present, and it looks odd.
        delegate.discussionVC(self, resetUnreadCount: discussion)
        
        return true
    }
    
    @objc private func close() {
        // Otherwise, on iPad, the progress indicator, if it's active, doesn't "transfer back" to the view controller using the discussion thread.
        if UIDevice.current.userInterfaceIdiom == .pad {
            delegate.discussionVCWillClose(self)
        }
        
        dismiss(animated: true, completion: nil)
    }
    
    @objc private func refresh() {
        delegate?.discussionVC(self, discussion: discussion, refreshWithCompletion: {[weak self] in
            // 3/25/19; Made self references weak. Got a crash here.
            self?.loadDiscussion()
            self?.messagesCollectionView.reloadData()
        })
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        // I can't get this to work in `viewWillAppear`. If it goes in `viewDidAppear`, I get the scrolling *after* the view appears, which doesn't look so good. Don't want it called more than once either.
        if !viewsLayedOut {
            viewsLayedOut = true
            messagesCollectionView.scrollToBottom()
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        Progress.session.viewController = self
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        closeHandler?()
    }
    
    func getInitialsFromSenderDisplayName(sender: Sender) -> String {
        var initials = ""
        let usernameComponents = sender.displayName.components(separatedBy: " ")
        for namePart in usernameComponents {
            let initial = String(namePart[namePart.startIndex])
            initials += initial
        }
        
        return initials
    }
}

extension DiscussionVC: MessagesDisplayDelegate {
    // MARK: - Text Messages

    func textColor(for message: MessageType, at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) -> UIColor {
        return isFromCurrentSender(message: message) ? .white : .darkText
    }

    func detectorAttributes(for detector: DetectorType, and message: MessageType, at indexPath: IndexPath) -> [NSAttributedString.Key : Any] {
        return MessageLabel.defaultAttributes
    }

    func enabledDetectors(for message: MessageType, at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) -> [DetectorType] {
        return [.url, .address, .phoneNumber, .date]
    }

    // MARK: - All Messages

    func backgroundColor(for message: MessageType, at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) -> UIColor {
        return isFromCurrentSender(message: message) ? UIColor(red: 69/255, green: 193/255, blue: 89/255, alpha: 1) : UIColor(red: 230/255, green: 230/255, blue: 230/255, alpha: 1)
    }

    func messageStyle(for message: MessageType, at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) -> MessageStyle {
        let corner: MessageStyle.TailCorner = isFromCurrentSender(message: message) ? .bottomRight : .bottomLeft
        return .bubbleTail(corner, .curved)
    }

    func configureAvatarView(_ avatarView: AvatarView, for message: MessageType, at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) {
        let initials = getInitialsFromSenderDisplayName(sender: message.sender)
        let avatar = Avatar(initials: initials)
        avatarView.set(avatar: avatar)
    }
}

extension DiscussionVC: MessagesLayoutDelegate {
    func cellTopLabelHeight(for message: MessageType, at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) -> CGFloat {
        if isPreviousMessageSameDay(at: indexPath) {
            return 10
        }
        else {
            return 35
        }
    }
    
    func messageTopLabelHeight(for message: MessageType, at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) -> CGFloat {
        return 20
    }
    
    func messageBottomLabelHeight(for message: MessageType, at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) -> CGFloat {
        return 16
    }
    
    func avatarPosition(for message: MessageType, at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) -> AvatarPosition {
        return AvatarPosition(horizontal: .natural, vertical: .messageBottom)
    }

    func messagePadding(for message: MessageType, at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) -> UIEdgeInsets {
        if isFromCurrentSender(message: message) {
            return UIEdgeInsets(top: 0, left: 30, bottom: 0, right: 4)
        } else {
            return UIEdgeInsets(top: 0, left: 4, bottom: 0, right: 30)
        }
    }
    
    // Prior to version 2.0.0 of MessageKit, I had a cellTopLabelAlignment delegate method in here (nor cellBottomLabelAlignment). Seems like (a) it's been removed and (b) it's not needed any more. See also https://github.com/MessageKit/MessageKit/issues/1041 and https://stackoverflow.com/questions/52583843/migration-to-1-0-0-messagekit-cocoapod-with-messageslayoutdelegate

    func footerViewSize(for message: MessageType, at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) -> CGSize {

        return CGSize(width: messagesCollectionView.bounds.width, height: 10)
    }

    // MARK: - Location Messages

    func heightForLocation(message: MessageType, at indexPath: IndexPath, with maxWidth: CGFloat, in messagesCollectionView: MessagesCollectionView) -> CGFloat {
        return 200
    }
}

extension DiscussionVC: MessagesDataSource {
    func numberOfSections(in messagesCollectionView: MessagesCollectionView) -> Int {
        return fixedObjects?.count ?? 0
    }
    
    func currentSender() -> Sender {        
        return Sender(id: senderUserId, displayName: senderUserDisplayName)
    }

    private func messageForItem(at indexPath: IndexPath) -> MessageType {
        // We've already checked to make sure the fixedObjects are valid.
        let dict = fixedObjects![indexPath.section] as! [String: String]
        let message = DiscussionMessage.fromDictionary(dict)!
        
        return message
    }
    
    func messageForItem(at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) -> MessageType {
        return messageForItem(at: indexPath)
    }
    
    private func isPreviousMessageSameDay(at indexPath: IndexPath) -> Bool {
        guard indexPath.section - 1 >= 0 else { return false }
        
        let currentMessage = messageForItem(at: indexPath)
        let currentMessageDate = currentMessage.sentDate
        
        let previousIndexPath = IndexPath(row: 0, section: indexPath.section - 1)
        let previousMessage = messageForItem(at: previousIndexPath)
        let previousMessageDate = previousMessage.sentDate
        
        return Calendar.current.isDate(currentMessageDate, inSameDayAs:previousMessageDate)
    }
    
    func cellTopLabelAttributedText(for message: MessageType, at indexPath: IndexPath) -> NSAttributedString? {
        struct CellDateFormatter {
            static let formatter: DateFormatter = {
                let formatter = DateFormatter()
                // See https://nsdateformatter.com
                formatter.dateFormat = "EEEE, MMM d, yyyy"
                return formatter
            }()
        }
        
        if !isPreviousMessageSameDay(at: indexPath) {
            let formatter = CellDateFormatter.formatter
            let dateString = formatter.string(from: message.sentDate)
            return NSAttributedString(string: dateString, attributes: [NSAttributedString.Key.font: UIFont.boldSystemFont(ofSize: 10), NSAttributedString.Key.foregroundColor: UIColor.darkGray])
        }
        
        return nil
    }
    
    func messageTopLabelAttributedText(for message: MessageType, at indexPath: IndexPath) -> NSAttributedString? {
        let name = message.sender.displayName
        return NSAttributedString(string: name, attributes: [NSAttributedString.Key.font: UIFont.preferredFont(forTextStyle: .caption1)])
    }

    func messageBottomLabelAttributedText(for message: MessageType, at indexPath: IndexPath) -> NSAttributedString? {
        
        struct BottomDateFormatter {
            static let formatter: DateFormatter = {
                let formatter = DateFormatter()
                // See https://nsdateformatter.com
                formatter.dateFormat = "MMM d, h:mm a"
                return formatter
            }()
        }
        
        let formatter = BottomDateFormatter.formatter
        let dateString = formatter.string(from: message.sentDate)
        let result = NSAttributedString(string: dateString, attributes: [NSAttributedString.Key.font: UIFont.preferredFont(forTextStyle: .caption2)])
        return result
    }
}

extension DiscussionVC: MessageCellDelegate {
    func didSelectURL(_ url: URL) {
        UIApplication.shared.open(url, options: [:], completionHandler: nil)
    }
    
    func didSelectPhoneNumber(_ phoneNumber: String) {
        phoneNumber.makeACall()
    }
    
    func didSelectAddress(_ addressComponents: [String : String]) {
        // It's not documented, but the keys are from NSTextCheckingKey. Having to do some machinations to get just a simple address string again to geocode it. See also https://github.com/MessageKit/MessageKit/issues/1043
        let keys = [NSTextCheckingKey.street.rawValue, NSTextCheckingKey.city.rawValue, NSTextCheckingKey.state.rawValue, NSTextCheckingKey.zip.rawValue]
        var address = ""
        
        for key in keys {
            if let value = addressComponents[key] {
                if address.count > 0 {
                    address += ", "
                }
                
                address += value
            }
        }
        
        guard address.count > 0 else {
            return
        }
    
        AddressNavigation.navigate(to: address, using: self)
    }
}

extension DiscussionVC: MessageInputBarDelegate {
    func messageInputBar(_ inputBar: MessageInputBar, didPressSendButtonWith text: String) {
        for component in inputBar.inputTextView.components {
            if let text = component as? String {
                let messageUUID = UUID.make()!
                let message = DiscussionMessage(messageId: messageUUID, sender: currentSender(), sentDate: Date(), sentTimezone: TimeZone.current.identifier, kind: .text(text))
                
                guard let fixedObject = message.toDictionary() else {
                    SMCoreLib.Alert.show(fromVC: self, withTitle: "Alert!", message: "Failed creating message!")
                    return
                }
                
                do {
                    try fixedObjects.add(newFixedObject: fixedObject)
                    try fixedObjects.save(toFile: fixedObjectsURL)
                } catch (let error) {
                    SMCoreLib.Alert.show(fromVC: self, withTitle: "Alert!", message: "Failed adding message: \(error)")
                }
                
                messagesCollectionView.insertSections([fixedObjects.count - 1])
                
                delegate.discussionVC(self, changedDiscussion: discussion)
            }
        }
        
        inputBar.inputTextView.text = String()
        messagesCollectionView.scrollToBottom()
    }
    
    func messageInputBar(_ inputBar: MessageInputBar, textViewTextDidChangeTo text: String) {
        if text.count > maxMessageLength {
            inputBar.inputTextView.text = text.substring(toIndex: maxMessageLength)
        }
    }
}

extension String {
    subscript (r: Range<Int>) -> String {
        let range = Range(uncheckedBounds: (lower: max(0, min(count, r.lowerBound)),
                                        upper: min(count, max(0, r.upperBound))))
        let start = index(startIndex, offsetBy: range.lowerBound)
        let end = index(start, offsetBy: range.upperBound - range.lowerBound)
        return String(self[start ..< end])
    }
    
    func substring(toIndex: Int) -> String {
        return self[0 ..< max(0, toIndex)]
    }
}

// From https://stackoverflow.com/questions/40078370/how-to-make-phone-call-in-ios-10-using-swift/52644570
extension String {
    enum RegularExpressions: String {
        case phone = "^\\s*(?:\\+?(\\d{1,3}))?([-. (]*(\\d{3})[-. )]*)?((\\d{3})[-. ]*(\\d{2,4})(?:[-.x ]*(\\d+))?)\\s*$"
    }

    func isValid(regex: RegularExpressions) -> Bool {
        return isValid(regex: regex.rawValue)
    }

    func isValid(regex: String) -> Bool {
        let matches = range(of: regex, options: .regularExpression)
        return matches != nil
    }

    func onlyDigits() -> String {
        let filtredUnicodeScalars = unicodeScalars.filter{CharacterSet.decimalDigits.contains($0)}
        return String(String.UnicodeScalarView(filtredUnicodeScalars))
    }

    func makeACall() {
        if isValid(regex: .phone) {
            if let url = URL(string: "tel://\(self.onlyDigits())"), UIApplication.shared.canOpenURL(url) {
                if #available(iOS 10, *) {
                    UIApplication.shared.open(url)
                } else {
                    UIApplication.shared.openURL(url)
                }
            }
        }
    }
}
