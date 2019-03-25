//
//  Menu.swift
//  SharedImages
//
//  Created by Christopher G Prince on 3/24/19.
//  Copyright © 2019 Spastic Muffin, LLC. All rights reserved.
//

import UIKit

class Menu: UIView, XibBasics {
    typealias ViewType = Menu
    private static var reuseIdCount = 0
    @IBOutlet private weak var tableView: UITableView!
    private var reuseId:String!
    private var menuItems:[MenuItem]?
    private var selection: ((_ rowIndex: Int)->())!
    
    var contentHeight: CGFloat {
        return tableView.contentSize.height
    }
    
    private var _selectedRowIndex: UInt?
    var selectedRowIndex: UInt? {
        set {
            setSelectedRowIndex(newValue, animated: true)
        }
        get {
            return _selectedRowIndex
        }
    }
    
    func setSelectedRowIndex(_ rowIndex: UInt?, animated: Bool) {
        _selectedRowIndex = rowIndex
        if _selectedRowIndex == nil {
            if let index = tableView.indexPathForSelectedRow {
                tableView.deselectRow(at: index, animated: animated)
            }
        }
        else {
            if let index = tableView.indexPathForSelectedRow {
                if UInt(index.row) != _selectedRowIndex {
                    tableView.deselectRow(at: index, animated: animated)
                    let indexPath = IndexPath(row: Int(_selectedRowIndex!), section: 0)
                    tableView.selectRow(at: indexPath, animated: animated, scrollPosition: .none)
                }
            }
            else {
                let indexPath = IndexPath(row: Int(_selectedRowIndex!), section: 0)
                tableView.selectRow(at: indexPath, animated: animated, scrollPosition: .none)
            }
        }
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        
        if reuseId == nil {
            reuseId = "ReuseId\(Menu.reuseIdCount)"
            Menu.reuseIdCount += 1
        }
        
        tableView.dataSource = self
        tableView.delegate = self
        
        tableView.register(UINib(nibName: typeName(SideMenuItem.self), bundle: nil), forCellReuseIdentifier: reuseId)
        tableView.rowHeight = UITableView.automaticDimension
    }
    
    struct MenuItem {
        let name: String
        let icon: UIImage
        let badgeValueGetter:(()->(Int?))?
        
        init(name: String, icon: UIImage, badgeValueGetter:(()->(Int?))? = nil) {
            self.name = name
            self.icon = icon
            self.badgeValueGetter = badgeValueGetter
        }
    }
    
    func setup(items: [MenuItem], selection: @escaping (_ rowIndex: Int)->()) {
        self.menuItems = items
        self.selection = selection
        tableView.reloadData()
    }
    
    func refreshBadges() {
        guard let indexPaths = tableView?.indexPathsForVisibleRows else {
            return
        }
        
        for indexPath in indexPaths {
            if let cell = tableView.cellForRow(at: indexPath) as? SideMenuItem {
                let itemContents = menuItems![indexPath.row]
                cell.badgeValue = itemContents.badgeValueGetter?()
            }
        }
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
        cell.badgeValue = itemContents.badgeValueGetter?()
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        _selectedRowIndex = UInt(indexPath.row)
        selection?(indexPath.row)
    }
}
