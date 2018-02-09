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
    func discussionVC(_ vc: DiscussionVC, changedDiscussion:Discussion)
}

class DiscussionVC: MessagesViewController {
    private var fixedObjectsURL: URL!
    private var fixedObjects:FixedObjects!
    var parentVC: UIViewController!
    private var closeHandler:(()->())?
    private var senderUserDisplayName:String!
    private var senderUserId:String!
    private var delegate:DiscussionVCDelegate!
    private var discussion: Discussion!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        messagesCollectionView.messagesDataSource = self
        messagesCollectionView.messagesLayoutDelegate = self
        messagesCollectionView.messagesDisplayDelegate = self
        messageInputBar.delegate = self

        messageInputBar.sendButton.tintColor = UIColor(red: 69/255, green: 193/255, blue: 89/255, alpha: 1)
        scrollsToBottomOnKeybordBeginsEditing = true // default false
        maintainPositionOnKeyboardFrameChanged = true // default false
    }
    
    // `closeHandler` gets called when the ModalVC gets closed.
    // Returns false iff the show failed.
    @discardableResult
    func show(fromParentVC parentVC: UIViewController, discussion: Discussion, delegate:DiscussionVCDelegate, usingNavigationController: Bool = true, closeHandler:(()->())? = nil) -> Bool {
    
        self.parentVC = parentVC
        self.closeHandler = closeHandler
        self.delegate = delegate
        self.discussion = discussion
        
        guard let url = discussion.url else {
            SMCoreLib.Alert.show(fromVC: parentVC, withTitle: "Problem loading messages", message: "The discussion had no URL!")
            return false
        }
        
        self.fixedObjectsURL = url as URL
        fixedObjects = FixedObjects(withFile: fixedObjectsURL)
        
        // Make sure that the file format containing the messages hasn't changed.
        for fixedObject in fixedObjects {
            guard let dict = fixedObject as? [String: String],
                let _ = DiscussionMessage.fromDictionary(dict) else {
                SMCoreLib.Alert.show(fromVC: parentVC, withTitle: "Problem loading messages", message: "Has there been a format change?")
                return false
            }
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
        
        let barButton = UIBarButtonItem(image: #imageLiteral(resourceName: "close"), style: .plain, target: self, action: #selector(close))
        navigationItem.rightBarButtonItem = barButton
        let nav = UINavigationController(rootViewController: self)
        
        if UIDevice.current.userInterfaceIdiom == .pad {
            nav.modalTransitionStyle = .coverVertical
            nav.modalPresentationStyle = .formSheet
        }
        
        parentVC.present(nav, animated: true, completion: nil)
        
        discussion.unreadCount = 0
        discussion.save()
        
        return true
    }
    
    @objc func close() {
        dismiss(animated: true, completion: nil)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
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

    func detectorAttributes(for detector: DetectorType, and message: MessageType, at indexPath: IndexPath) -> [NSAttributedStringKey : Any] {
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
        return NSAttributedString(string: name, attributes: [NSAttributedStringKey.font: UIFont.preferredFont(forTextStyle: .caption1)])
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
        return NSAttributedString(string: dateString, attributes: [NSAttributedStringKey.font: UIFont.preferredFont(forTextStyle: .caption2)])
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
}
