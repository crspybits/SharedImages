//
//  ShareAlbumVC.swift
//  SharedImages
//
//  Created by Christopher G Prince on 4/2/19.
//  Copyright © 2019 Spastic Muffin, LLC. All rights reserved.
//

import UIKit
import Presentr

class ShareAlbumVC: UIViewController {
    @IBOutlet private weak var navBar: UINavigationBar!
    @IBOutlet private weak var tableView: UITableView!
    private static let modalHeight = ModalSize.sideMargin(value: 40)
    private static let modalWidth = ModalSize.sideMargin(value: 20)
    private let numberInviteesReuseId = "numberInviteesReuseId"
    private let permissionReuseId = "permissionReuseId"
    private let helpReuseId = "helpReuseId"

    // These correspond to row numbers in the table view.
    private enum CellType: Int {
        case numberInvitees = 0
        case permission = 1
        case help = 2
        
        // This *must* reflect the number of cases.
        static let numberTypes = 3
    }
    
    private static let customTypePortrait: PresentationType = {
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
    
    static func show(fromParentVC parentVC: UIViewController) {
        let shareAlbum = ShareAlbumVC.create()
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
        tableView.register(UINib(nibName: "ShareAlbumHelpCell", bundle: nil), forCellReuseIdentifier: helpReuseId)
        tableView.separatorStyle = .none
        tableView.allowsSelection = false
        
        // Dealing with problems with slider UI
        tableView.delaysContentTouches = false
    }
}

extension ShareAlbumVC: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return CellType.numberTypes
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cellType = CellType(rawValue: indexPath.row) else {
            return UITableViewCell()
        }
        
        switch cellType {
        case .numberInvitees:
            let cell = tableView.dequeueReusableCell(withIdentifier: numberInviteesReuseId, for: indexPath)
            return cell
        case .permission:
            let cell = tableView.dequeueReusableCell(withIdentifier: permissionReuseId, for: indexPath)
            return cell
        case .help:
            let cell = tableView.dequeueReusableCell(withIdentifier: helpReuseId, for: indexPath)
            return cell
        }
    }
}
