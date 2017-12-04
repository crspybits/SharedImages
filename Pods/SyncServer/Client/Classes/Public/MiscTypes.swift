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

// Attributes for a file being synced.
public struct SyncAttributes {
    public var fileUUID:String!
    public var mimeType:String!
    
    // 11/18/17; Are these two used any more? I think we're not relying any more on the client's dates-- because (a) client's aren't generally reliable, and (b) we get odd date issues when a client queues a file for upload, but that upload is delayed, e.g., because of a lack of a network connection.
    public var creationDate:Date?
    public var updateDate:Date?
    
    
    public var appMetaData:String?
    
    public init(fileUUID:String, mimeType:String, creationDate: Date? = nil, updateDate: Date? = nil) {
        self.fileUUID = fileUUID
        self.mimeType = mimeType
        self.creationDate = creationDate
        self.updateDate = updateDate
    }
}



