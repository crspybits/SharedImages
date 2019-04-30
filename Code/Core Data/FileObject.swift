//
//  FileObject+CoreDataClass.swift
//  SharedImages
//
//  Created by Christopher G Prince on 4/18/19.
//  Copyright © 2019 Spastic Muffin, LLC. All rights reserved.
//
//

import Foundation
import CoreData
import SMCoreLib
import SyncServer_Shared

@objc(FileObject)
public class FileObject: NSManagedObject {
    static let UUID_KEY = "uuid"

    var url:SMRelativeLocalURL? {
        get {
            return CoreData.getSMRelativeLocalURL(fromCoreDataProperty: urlInternal as Data?)
        }
        
        set {
            if newValue == nil {
                urlInternal = nil
            }
            else {
                urlInternal = NSKeyedArchiver.archivedData(withRootObject: newValue!) as NSData?
            }
        }
    }
    
    var gone:GoneReason? {
        get {
            if let goneReasonInternal = goneReasonInternal {
                return GoneReason(rawValue: goneReasonInternal)
            }
            else {
                return nil
            }
        }
        
        set {
            goneReasonInternal = newValue?.rawValue
        }
    }
    
    var hasError: Bool {
        return gone != nil || readProblem
    }
    
    func save() {
        CoreData.sessionNamed(CoreDataExtras.sessionName).saveContext()
    }
}
