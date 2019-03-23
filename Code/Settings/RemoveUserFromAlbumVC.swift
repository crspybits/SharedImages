//
//  RemoveUserFromAlbumVC.swift
//  SharedImages
//
//  Created by Christopher G Prince on 3/22/19.
//  Copyright © 2019 Spastic Muffin, LLC. All rights reserved.
//

import Foundation
import UIKit
import SyncServer
import SMCoreLib

class RemoveUserFromAlbumVC: UIViewController {
    @IBOutlet private weak var tableView: UITableView!
    private var sharingGroups:[SyncServer.SharingGroup]!
    private let reuseId = "ReuseId"
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        title = "Remove User from Album"

        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: reuseId)
        
        sharingGroups = SyncServer.session.sharingGroups
        sharingGroups.sort { sg1, sg2 in
            if let name1 = sg1.sharingGroupName, let name2 = sg2.sharingGroupName {
                return name1 < name2
            }
            else {
                return false
            }
        }
    }
    
    private func removeUserFromAlbum(sharingGroup: SyncServer.SharingGroup, completion:@escaping ()->()) {
        var album = ""
        if let name = sharingGroup.sharingGroupName {
            album = " '\(name)'"
        }
        
        let alert = UIAlertController(title: "Remove you from the\(album) album?", message: "This will permanently remove the album from the Neebla app on your device(s). Other users (if any) can still use the album, but they won't have access to your images. If images have been stored in your cloud storage, they will still be in your cloud storage.", preferredStyle: .actionSheet)
        alert.popoverPresentationController?.sourceView = self.view
        Alert.styleForIPad(alert)

        alert.addAction(UIAlertAction(title: "Cancel", style: .default) {alert in
            completion()
        })
        
        alert.addAction(UIAlertAction(title: "OK", style: .destructive) {alert in
            do {
                try SyncServer.session.removeFromSharingGroup(sharingGroupUUID: sharingGroup.sharingGroupUUID)
                try SyncServer.session.sync(sharingGroupUUID: sharingGroup.sharingGroupUUID)
                
                // The delegate removes references/files to the images/discussions.
                self.navigationController?.popViewController(animated: true)
                completion()
            } catch (let error) {
                Log.error("\(error)")
                SMCoreLib.Alert.show(fromVC: self, withTitle: "Alert!", message: "Could not remove you from the album! Please try again later.")
                completion()
                return
            }
        })
        
        self.present(alert, animated: true, completion: nil)
    }
}

extension RemoveUserFromAlbumVC: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return sharingGroups.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: reuseId, for: indexPath)
        let sharingGroup = sharingGroups[indexPath.row]
        if let name = sharingGroup.sharingGroupName {
            cell.textLabel?.text = name
        }
        else {
            cell.textLabel?.text = "Album"
        }
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let sharingGroup = sharingGroups[indexPath.row]
        removeUserFromAlbum(sharingGroup: sharingGroup) {
            tableView.deselectRow(at: indexPath, animated: true)
        }
    }
}
