//
//  MiscTypes.swift
//  Pods
//
//  Created by Christopher Prince on 2/23/17.
//
//

import Foundation
import SMCoreLib

public typealias AppMetaData = [String:AnyObject]
public typealias UUIDString = String

public protocol FileUUID {
    var fileUUID:UUIDString! {get}
}

// Attributes for a file being synced.
public struct SyncAttributes : FileUUID {
    public var fileUUID:UUIDString!
    public var mimeType:String!
    
    // 12/27/17; These only get used for responses from the server-- because it is the authority on dates.
    public var creationDate:Date?
    public var updateDate:Date?
    
    public var appMetaData:String?
    
    public init(fileUUID:UUIDString, mimeType:String, creationDate: Date? = nil, updateDate: Date? = nil) {
        self.fileUUID = fileUUID
        self.mimeType = mimeType
        self.creationDate = creationDate
        self.updateDate = updateDate
    }
}



