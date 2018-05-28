//
//  Parameters.swift
//  SharedImages
//
//  Created by Christopher G Prince on 5/21/18.
//  Copyright © 2018 Spastic Muffin, LLC. All rights reserved.
//

import Foundation
import SMCoreLib

class Parameters {
    private init() {}

    enum SortOrder : Int {
        case creationDate = 0
    }
    
    private static let _sortingOrder = SMPersistItemInt(name: "Parameters.sortingOrder", initialIntValue: SortOrder.creationDate.rawValue, persistType: .userDefaults)
    static var sortingOrder:SortOrder {
        set {
            _sortingOrder.intValue = newValue.rawValue
        }
        get {
            if let result = SortOrder(rawValue: _sortingOrder.intValue) {
                return result
            }
            return SortOrder.creationDate
        }
    }
    
    // Separate out the ascending/descending values because I want these to persist even when a particular sort order is not selected.
    private static let _creationDateAscending = SMPersistItemBool(name: "Parameters.creationDateAscending", initialBoolValue: true, persistType: .userDefaults)
    static var creationDateAscending: Bool {
        set {
            _creationDateAscending.boolValue = newValue
        }
        
        get {
            return _creationDateAscending.boolValue
        }
    }
    
    static var sortingOrderIsAscending:Bool {
        switch sortingOrder {
        case .creationDate:
            return Parameters.creationDateAscending
        }
    }
    
    enum UnreadCounts: String {
        case all = "All"
        case unread = "Only Unread"
    }

    private static let _unreadCountsFilter = SMPersistItemString(name: "Parameters.unreadCountsFilter", initialStringValue: UnreadCounts.all.rawValue, persistType: .userDefaults)
    static var unreadCounts:UnreadCounts {
        set {
            _unreadCountsFilter.stringValue = newValue.rawValue
        }
        get {
            if let result = UnreadCounts(rawValue: _unreadCountsFilter.stringValue) {
                return result
            }
            return .all
        }
    }
    
    static var filterApplied:Bool {
        return unreadCounts != .all
    }
}
