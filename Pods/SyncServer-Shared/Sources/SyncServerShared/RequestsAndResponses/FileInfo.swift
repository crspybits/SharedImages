//
//  FileInfo.swift
//  Server
//
//  Created by Christopher Prince on 2/18/17.
//
//

import Foundation

public class FileInfo : Codable, CustomStringConvertible, Filenaming, Hashable {
    required public init() {}

    public var hashValue: Int {
        return fileUUID.hashValue
    }
    
    public static func ==(lhs: FileInfo, rhs: FileInfo) -> Bool {
        return lhs.fileUUID == rhs.fileUUID
    }
    
    public var fileUUID: String!
    public var deviceUUID: String?
    public var fileGroupUUID: String?
    public var sharingGroupUUID:String!

    // The creation & update dates are not used on upload-- they are established from dates on the server so they are not dependent on possibly mis-behaving clients.
    public var creationDate: Date?
 
    // Based on updating the contents only (not purely app meta data updates). I.e., calls to UploadFile.
    public var updateDate: Date?
    
    public var mimeType: String?
    
    public var deleted:Bool! = false

    // Optional because this will be nil if a file has no app meta data.
    public var appMetaDataVersion: AppMetaDataVersionInt?
    
    public var fileVersion: FileVersionInt!
    
    // OWNER
    public var owningUserId: UserId!
    
    public var cloudStorageType: String!
    
    public var description: String {
        return "fileUUID: \(String(describing: fileUUID)); deviceUUID: \(String(describing: deviceUUID)); creationDate: \(String(describing: creationDate)); updateDate: \(String(describing: updateDate)); mimeTypeKey: \(String(describing: mimeType)); deleted: \(String(describing: deleted)); fileVersion: \(String(describing: fileVersion)); appMetaDataVersion: \(String(describing: appMetaDataVersion))"
    }
}

