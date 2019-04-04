//
//  ShareAlbumVC.swift
//  SharedImages
//
//  Created by Christopher G Prince on 4/2/19.
//  Copyright © 2019 Spastic Muffin, LLC. All rights reserved.
//

import UIKit
import Presentr
import SyncServer_Shared
import SyncServer

class ShareAlbumVC: UIViewController {
    @IBOutlet private weak var navBar: UINavigationBar!
    @IBOutlet private weak var tableView: UITableView!
    private let numberInviteesReuseId = "numberInviteesReuseId"
    private let permissionReuseId = "permissionReuseId"
    private let allowSocialReuseId = "allowSocialReuseId"
    private let helpReuseId = "helpReuseId"

    // These correspond to row numbers in the table view.
    private enum CellType: Int {
        case numberInvitees = 0
        case permission = 1
        case allowSocial = 2
        case help = 3
        
        // This *must* reflect the number of cases.
        static let numberTypes = 4
    }
    
    private var cancel:(()->())!
    private var invite:((InvitationParameters)->())!
    private var sharingGroup: SyncServer.SharingGroup!
    
    // Cached cells because I don't actually want them reused so I can retain the UI state.
    // Keyed by re-use id.
    private var cachedCells = [String: UITableViewCell]()
    
    private static let customTypePortrait: PresentationType = {
        let modalHeight:ModalSize
        let modalWidth:ModalSize
        
        if UIDevice.current.userInterfaceIdiom == .pad {
            modalHeight = .fluid(percentage: 0.75)
            modalWidth = .half
        }
        else {
            modalHeight = .sideMargin(value: 40)
            modalWidth = .sideMargin(value: 20)
        }
        
        let center = ModalCenterPosition.center
        let customType = PresentationType.custom(width: modalWidth, height: modalHeight, center: center)
        return customType
    }()
    
    private let presenter: Presentr = {
        let customPresenter = Presentr(presentationType: ShareAlbumVC.customTypePortrait)
        customPresenter.transitionType = .coverVerticalFromTop
        customPresenter.dismissTransitionType = .crossDissolve
        customPresenter.roundCorners = false
        customPresenter.backgroundOpacity = 0.5
        customPresenter.dismissOnSwipe = true
        customPresenter.dismissOnSwipeDirection = .top
    
        return customPresenter
    }()
    
    struct InvitationParameters {
        let numberAcceptors: UInt
        let permission: Permission
        let allowSocialAcceptance:Bool
    }
    
    static func show(fromParentVC parentVC: UIViewController, sharingGroup: SyncServer.SharingGroup, cancel:@escaping ()->(), invite:@escaping (InvitationParameters)->()) {
        let shareAlbum = ShareAlbumVC.create()
        shareAlbum.sharingGroup = sharingGroup
        shareAlbum.invite = invite
        shareAlbum.cancel = cancel
        parentVC.customPresentViewController(shareAlbum.presenter, viewController: shareAlbum, animated: true, completion: nil)
    }
    
    static func create() -> ShareAlbumVC {
        return UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "ShareAlbumVC") as! ShareAlbumVC
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = .white
        tableView.delegate = self
        tableView.dataSource = self
        tableView.rowHeight = UITableView.automaticDimension
        tableView.register(UINib(nibName: "ShareAlbumNumberInviteesCell", bundle: nil), forCellReuseIdentifier: numberInviteesReuseId)
        tableView.register(UINib(nibName: "ShareAlbumPermissionCell", bundle: nil), forCellReuseIdentifier: permissionReuseId)
        tableView.register(UINib(nibName: "ShareAlbumAllowSocialCell", bundle: nil), forCellReuseIdentifier: allowSocialReuseId)
        tableView.register(UINib(nibName: "ShareAlbumHelpCell", bundle: nil), forCellReuseIdentifier: helpReuseId)
        tableView.separatorStyle = .none
        tableView.allowsSelection = false
        
        // Dealing with problems with slider UI on ShareAlbumNumberInviteesCell; see https://stackoverflow.com/questions/37316026/uitableview-cell-with-slider-touch-not-working-correctly-swift-2
        tableView.delaysContentTouches = false
        
        var albumName = "Album"
        if let name = sharingGroup.sharingGroupName {
            albumName = "'\(name)'"
        }
        let title = "Invite Others to " + albumName
        let item = UINavigationItem(title: title)
        navBar.items = [item]
    }
    
    @IBAction func inviteAction(_ sender: Any) {
        let permissionCell = getCell(reuseId: permissionReuseId, cellType: .permission) as! ShareAlbumPermissionCell
        let numberAcceptorsCell = getCell(reuseId: numberInviteesReuseId, cellType: .numberInvitees) as! ShareAlbumNumberInviteesCell
        let allowSocialAcceptanceCell = getCell(reuseId: allowSocialReuseId, cellType: .allowSocial) as! ShareAlbumAllowSocialCell
        let params = InvitationParameters(numberAcceptors: numberAcceptorsCell.currSliderValue, permission: permissionCell.permission, allowSocialAcceptance: allowSocialAcceptanceCell.switch.isOn)
        
        dismiss(animated: true, completion: {
            self.invite?(params)
        })
    }
    
    @IBAction func cancelAction(_ sender: Any) {
        dismiss(animated: true, completion: cancel)
    }
}

extension ShareAlbumVC: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return CellType.numberTypes
    }
    
    private func getCell(reuseId: String, cellType: CellType) -> UITableViewCell {
        if let cell = cachedCells[reuseId] {
            return cell
        }
        else {
            let indexPath = IndexPath(row: cellType.rawValue, section: 0)
            let cell = tableView.dequeueReusableCell(withIdentifier: reuseId, for: indexPath)
            cachedCells[reuseId] = cell
            return cell
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cellType = CellType(rawValue: indexPath.row) else {
            return UITableViewCell()
        }
        
        switch cellType {
        case .numberInvitees:
            return getCell(reuseId: numberInviteesReuseId, cellType: cellType)
        case .permission:
            return getCell(reuseId: permissionReuseId, cellType: cellType)
        case .allowSocial:
            return getCell(reuseId: allowSocialReuseId, cellType: cellType)
        case .help:
            return getCell(reuseId: helpReuseId, cellType: cellType)
        }
    }
}
