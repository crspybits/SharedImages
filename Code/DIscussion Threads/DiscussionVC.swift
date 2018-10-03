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

protocol DiscussionVCDelegate {
    func discussionVC(_ vc: DiscussionVC, resetUnreadCount:Discussion)
    func discussionVC(_ vc: DiscussionVC, changedDiscussion:Discussion)
    func discussionVC(_ vc: DiscussionVC, discussion:Discussion, refreshWithCompletion: (()->())?)
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
    private var discussion: Discussion!
    private var viewsLayedOut = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        messagesCollectionView.messagesDataSource = self
        messagesCollectionView.messagesLayoutDelegate = self
        messagesCollectionView.messagesDisplayDelegate = self
        messageInputBar.delegate = self
        
        // 2/13/18; See https://github.com/crspybits/SharedImages/issues/81 and see https://github.com/MessageKit/MessageKit/issues/518
        messageInputBar.sendButton.titleLabel?.font = UIFont.systemFont(ofSize: 22.0)

        messageInputBar.sendButton.tintColor = UIColor(red: 69/255, green: 193/255, blue: 89/255, alpha: 1)
        scrollsToBottomOnKeybordBeginsEditing = true // default false
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
    func show(fromParentVC parentVC: UIViewController, discussion: Discussion, delegate:DiscussionVCDelegate, usingNavigationController: Bool = true, closeHandler:(()->())? = nil) -> Bool {
    
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
        navigationItem.rightBarButtonItem = closeBarButton
        
        let refreshBarButton = UIBarButtonItem(barButtonSystemItem: .refresh, target: self, action: #selector(refresh))
        navigationItem.leftBarButtonItem = refreshBarButton
        
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
        UnreadCountBadge.update()

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
        delegate?.discussionVC(self, discussion: discussion, refreshWithCompletion: {[unowned self] in
            self.loadDiscussion()
            self.messagesCollectionView.reloadData()
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

    // The following two delegate methods fail with v1.0.0: See https://stackoverflow.com/questions/52583843/migration-to-1-0-0-messagekit-cocoapod-with-messageslayoutdelegate
    func cellTopLabelAlignment(for message: MessageType, at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) -> LabelAlignment {
        if isFromCurrentSender(message: message) {
            return .messageTrailing(UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 10))
        } else {
            return .messageLeading(UIEdgeInsets(top: 0, left: 10, bottom: 0, right: 0))
        }
    }

    func cellBottomLabelAlignment(for message: MessageType, at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) -> LabelAlignment {
        if isFromCurrentSender(message: message) {
            return .messageLeading(UIEdgeInsets(top: 0, left: 10, bottom: 0, right: 0))
        } else {
            return .messageTrailing(UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 10))
        }
    }

    func footerViewSize(for message: MessageType, at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) -> CGSize {

        return CGSize(width: messagesCollectionView.bounds.width, height: 10)
    }

    // MARK: - Location Messages

    func heightForLocation(message: MessageType, at indexPath: IndexPath, with maxWidth: CGFloat, in messagesCollectionView: MessagesCollectionView) -> CGFloat {
        return 200
    }
}

extension DiscussionVC: MessagesDataSource {
    func currentSender() -> Sender {        
        return Sender(id: senderUserId, displayName: senderUserDisplayName)
    }

    func numberOfMessages(in messagesCollectionView: MessagesCollectionView) -> Int {
        return fixedObjects?.count ?? 0
    }

    func messageForItem(at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) -> MessageType {
        
        // We've already checked to make sure the fixedObjects are valid.
        let dict = fixedObjects![indexPath.section] as! [String: String]
        let message = DiscussionMessage.fromDictionary(dict)!
        
        return message
    }

    func cellTopLabelAttributedText(for message: MessageType, at indexPath: IndexPath) -> NSAttributedString? {
        let name = message.sender.displayName
        return NSAttributedString(string: name, attributes: [NSAttributedString.Key.font: UIFont.preferredFont(forTextStyle: .caption1)])
    }

    func cellBottomLabelAttributedText(for message: MessageType, at indexPath: IndexPath) -> NSAttributedString? {
        
        struct ConversationDateFormatter {
            static let formatter: DateFormatter = {
                let formatter = DateFormatter()
                formatter.dateStyle = .medium
                return formatter
            }()
        }
        
        let formatter = ConversationDateFormatter.formatter
        let dateString = formatter.string(from: message.sentDate)
        return NSAttributedString(string: dateString, attributes: [NSAttributedString.Key.font: UIFont.preferredFont(forTextStyle: .caption2)])
    }
}

extension DiscussionVC: MessageInputBarDelegate {
    func messageInputBar(_ inputBar: MessageInputBar, didPressSendButtonWith text: String) {
        for component in inputBar.inputTextView.components {
            if let text = component as? String {
                let messageUUID = UUID.make()!
                let message = DiscussionMessage(messageId: messageUUID, sender: currentSender(), sentDate: Date(), sentTimezone: TimeZone.current.identifier, data: .text(text))
                
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
