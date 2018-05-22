//
//  SortyFilter.swift
//  SharedImages
//
//  Created by Christopher G Prince on 5/21/18.
//  Copyright © 2018 Spastic Muffin, LLC. All rights reserved.
//

import Foundation
import Presentr
import DropDown

protocol SortyFilterDelegate : class {
    func sortyFilter(sortFilterByParameters: SortyFilter)
}

class SortyFilter: UIViewController {
    @IBOutlet weak var sortingControls: UIView!
    var sortControls:[Parameters.SortOrder: SortControl]!
    var segmentedControl:SegmentedControl!
    @IBOutlet weak var onlyUnreadButton: UIButton!
    let onlyUnreadDropdown = DropDown()
    @IBOutlet weak var navItem: UINavigationItem!
    
    static let modalHeight = ModalSize.custom(size: 251)
    static let modalWidth = ModalSize.full
    
    static let customTypePortrait: PresentationType = {
        let center = ModalCenterPosition.customOrigin(origin: CGPoint(x: 0, y: 0))
        let customType = PresentationType.custom(width: SortyFilter.modalWidth, height: SortyFilter.modalHeight, center: center)
        return customType
    }()
    
    let presenter: Presentr = {
        let customPresenter = Presentr(presentationType: SortyFilter.customTypePortrait)
        customPresenter.transitionType = .coverVerticalFromTop
        customPresenter.dismissTransitionType = .crossDissolve
        customPresenter.roundCorners = false
        customPresenter.backgroundOpacity = 0.5
        customPresenter.dismissOnSwipe = true
        customPresenter.dismissOnSwipeDirection = .top
    
        return customPresenter
    }()
    
    private weak var delegate:SortyFilterDelegate!
    
    static func show(fromParentVC parentVC: UIViewController, delegate: SortyFilterDelegate) {
        let sortyFilter = SortyFilter()
        sortyFilter.delegate = delegate
        parentVC.customPresentViewController(sortyFilter.presenter, viewController: sortyFilter, animated: true, completion: nil)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = .white
        
        let creationDate = SortControl.create()!
        creationDate.setup(withName: "Date")
        creationDate.currState = Parameters.creationDateAscending ? .ascending : .descending
        
        sortControls = [.creationDate: creationDate]
        let components = [creationDate]
        
        segmentedControl = SegmentedControl(withComponents: components)
        segmentedControl.delegate = self
        sortingControls.addSubview(segmentedControl)


        onlyUnreadButton.setTitle(Parameters.unreadCounts.rawValue, for: .normal)
        
        setupDropdowns()
        
        let close = UIBarButtonItem(title: "Close", style: .plain, target: self, action: #selector(closeAction))
        navItem.leftBarButtonItem = close
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    }
    
    private func formatMiles(_ miles: Int) -> String {
        return "\(miles) miles"
    }
    
    private func setupDropdowns() {
        onlyUnreadDropdown.anchorView = onlyUnreadButton
        onlyUnreadDropdown.dismissMode = .automatic
        onlyUnreadDropdown.direction = .any
        
        onlyUnreadDropdown.selectionAction = { [unowned self] (index, item) in
            self.onlyUnreadButton.setTitle(item, for: .normal)
            if let result = Parameters.UnreadCounts(rawValue: item) {
                Parameters.unreadCounts = result
                self.delegate.sortyFilter(sortFilterByParameters: self)
            }
            self.onlyUnreadDropdown.hide()
        }

        onlyUnreadDropdown.dataSource = [Parameters.UnreadCounts.all.rawValue, Parameters.UnreadCounts.unread.rawValue]
    }
    
    @IBAction func onlyUnreadAction(_ sender: Any) {
        if let index = onlyUnreadDropdown.dataSource.index(where: {$0 == Parameters.unreadCounts.rawValue }) {
            onlyUnreadDropdown.selectRow(index)
        }
        
        onlyUnreadDropdown.show()
    }
    
    @objc func closeAction(_ sender: Any) {
        dismiss(animated: true, completion: nil)
    }
}

extension SortyFilter: SegmentedControlDelegate {
    func segmentedControlChanged(_ segmentedControl: SegmentedControl, selectionToIndex index: UInt) {
    
        guard let sortOrder = Parameters.SortOrder(rawValue: Int(index)),
            let sortControl = sortControls[sortOrder] else {
            return
        }
        
        let ascending = sortControl.currState == .ascending
        
        Parameters.sortingOrder = sortOrder
        
        switch sortOrder {
        case .creationDate:
            Parameters.creationDateAscending = ascending
        }
        
        self.delegate.sortyFilter(sortFilterByParameters: self)
    }
}
