//
//  FileInfo.swift
//  Server
//
//  Created by Christopher Prince on 2/18/17.
//
//

import Foundation
import Gloss

#if SERVER
import Kitura
#endif

public class FileInfo : Gloss.Encodable, Gloss.Decodable, CustomStringConvertible, Filenaming {
    public static let fileUUIDKey = "fileUUID"
    public var fileUUID: String!
    
    public static let deviceUUIDKey = "deviceUUID"
    public var deviceUUID: String?
    
    // The creation & update dates are not used on upload-- they are established from dates on the server so they are not dependent on possibly mis-behaving clients.
    
    public static let creationDateKey = "creationDate"
    public var creationDate: Date?
 
    public static let updateDateKey = "updateDate"
    public var updateDate: Date?
    
    public static let cloudFolderNameKey = "cloudFolderName"
    public var cloudFolderName: String?
    
    public static let mimeTypeKey = "mimeType"
    public var mimeType: String?
    
    public static let appMetaDataKey = "appMetaData"
    public var appMetaData: String?
    
    public static let deletedKey = "deleted"
    public var deleted:Bool! = false
    
    public static let fileVersionKey = "fileVersion"
    public var fileVersion: FileVersionInt!
    
    public static let fileSizeBytesKey = "fileSizeBytes"
    public var fileSizeBytes: Int64!
    
    public var description: String {
        return "fileUUID: \(fileUUID); deviceUUID: \(String(describing: deviceUUID)); creationDate: \(String(describing: creationDate)); updateDate: \(String(describing: updateDate)); mimeTypeKey: \(String(describing: mimeType)); appMetaData: \(String(describing: appMetaData)); deleted: \(deleted); fileVersion: \(fileVersion); fileSizeBytes: \(fileSizeBytes); cloudFolderName: \(String(describing: cloudFolderName))"
    }
    
    required public init?(json: JSON) {
        self.fileUUID = FileInfo.fileUUIDKey <~~ json
        self.deviceUUID = FileInfo.deviceUUIDKey <~~ json
        self.mimeType = FileInfo.mimeTypeKey <~~ json
        self.appMetaData = FileInfo.appMetaDataKey <~~ json
        self.deleted = FileInfo.deletedKey <~~ json
        
        self.fileVersion = Decoder.decode(int32ForKey: FileInfo.fileVersionKey)(json)
        self.fileSizeBytes = Decoder.decode(int64ForKey: FileInfo.fileSizeBytesKey)(json)
        
        self.cloudFolderName = FileInfo.cloudFolderNameKey <~~ json
        
        let dateFormatter = DateExtras.getDateFormatter(format: .DATETIME)
        self.creationDate = Decoder.decode(dateForKey: FileInfo.creationDateKey, dateFormatter: dateFormatter)(json)
        self.updateDate = Decoder.decode(dateForKey: FileInfo.updateDateKey, dateFormatter: dateFormatter)(json)
    }
    
    public convenience init?() {
        self.init(json:[:])
    }
    
    public func toJSON() -> JSON? {
        let dateFormatter = DateExtras.getDateFormatter(format: .DATETIME)

        return jsonify([
            FileInfo.fileUUIDKey ~~> self.fileUUID,
            FileInfo.deviceUUIDKey ~~> self.deviceUUID,
            FileInfo.mimeTypeKey ~~> self.mimeType,
            FileInfo.appMetaDataKey ~~> self.appMetaData,
            FileInfo.deletedKey ~~> self.deleted,
            FileInfo.fileVersionKey ~~> self.fileVersion,
            FileInfo.fileSizeBytesKey ~~> self.fileSizeBytes,
            FileInfo.cloudFolderNameKey ~~> self.cloudFolderName,
            Encoder.encode(dateForKey: FileInfo.creationDateKey, dateFormatter: dateFormatter)(self.creationDate),
            Encoder.encode(dateForKey: FileInfo.updateDateKey, dateFormatter: dateFormatter)(self.updateDate)
        ])
    }
}

