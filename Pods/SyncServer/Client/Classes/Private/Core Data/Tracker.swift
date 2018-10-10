//
//  Tracker+CoreDataClass.swift
//  SyncServer
//
//  Created by Christopher G Prince on 9/3/18.
//
//

import Foundation
import CoreData

@objc(Tracker)
public class Tracker: NSManagedObject {
    public enum Operation: String {
        case sharingGroup // Create, update, remove user uploads
        case file // File upload or download
        case appMetaData // appMetaData upload or download.
        case deletion // Upload or download deletion
        
        var isContents: Bool {
            return self == .file || self == .appMetaData
        }
        
        var isDeletion: Bool {
            return self == .deletion
        }
    }
    
    public var operation: Operation! {
        get {
            return operationInternal == nil ? nil : Operation(rawValue: operationInternal!)
        }
        
        set {
            operationInternal = newValue.rawValue
        }
    }
}
