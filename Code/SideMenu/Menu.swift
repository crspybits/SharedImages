//
//  Menu.swift
//  SharedImages
//
//  Created by Christopher G Prince on 3/24/19.
//  Copyright © 2019 Spastic Muffin, LLC. All rights reserved.
//

import UIKit

class Menu: UIViewXib {
    typealias ViewType = Menu
    @IBOutlet private weak var tableView: UITableView!
    private let reuseId = "ReuseId"
    private var menuItems:[MenuItem]?
    private var selection: ((_ rowIndex: Int)->())!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        
        tableView.dataSource = self
        tableView.delegate = self
        
        tableView.register(UINib(nibName: typeName(SideMenuItem.self), bundle: nil), forCellReuseIdentifier: reuseId)
        tableView.rowHeight = UITableView.automaticDimension
    }
    
    struct MenuItem {
        let name: String
        let icon: UIImage
    }
    
    func setup(items: [MenuItem], selection: @escaping (_ rowIndex: Int)->()) {
        self.menuItems = items
        self.selection = selection
        tableView.reloadData()
    }
}

extension Menu: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return menuItems?.count ?? 0
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: reuseId, for: indexPath) as! SideMenuItem
        let itemContents = menuItems![indexPath.row]
        cell.menuItem.text = itemContents.name
        cell.icon.image = itemContents.icon
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        selection?(indexPath.row)
    }
}
