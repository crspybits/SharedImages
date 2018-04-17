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

public class FileInfo : Gloss.Encodable, Gloss.Decodable, CustomStringConvertible, Filenaming, Hashable {

    public var hashValue: Int {
        return fileUUID.hashValue
    }
    
    public static func ==(lhs: FileInfo, rhs: FileInfo) -> Bool {
        return lhs.fileUUID == rhs.fileUUID
    }
    
    public static let fileUUIDKey = "fileUUID"
    public var fileUUID: String!
    
    public static let deviceUUIDKey = "deviceUUID"
    public var deviceUUID: String?
    
    // The creation & update dates are not used on upload-- they are established from dates on the server so they are not dependent on possibly mis-behaving clients.
    
    public static let creationDateKey = "creationDate"
    public var creationDate: Date?
 
    // Based on updating the contents only (not purely app meta data updates). I.e., calls to UploadFile.
    public static let updateDateKey = "updateDate"
    public var updateDate: Date?
    
    public static let mimeTypeKey = "mimeType"
    public var mimeType: String?
    
    public static let deletedKey = "deleted"
    public var deleted:Bool! = false

    // Optional because this will be nil if a file has no app meta data.
    public static let appMetaDataVersionKey = "appMetaDataVersion"
    public var appMetaDataVersion: AppMetaDataVersionInt?
    
    public static let fileVersionKey = "fileVersion"
    public var fileVersion: FileVersionInt!
    
    public static let fileSizeBytesKey = "fileSizeBytes"
    public var fileSizeBytes: Int64!
    
    public var description: String {
        return "fileUUID: \(fileUUID); deviceUUID: \(String(describing: deviceUUID)); creationDate: \(String(describing: creationDate)); updateDate: \(String(describing: updateDate)); mimeTypeKey: \(String(describing: mimeType)); deleted: \(deleted); fileVersion: \(fileVersion); appMetaDataVersion: \(String(describing: appMetaDataVersion)); fileSizeBytes: \(fileSizeBytes)"
    }
    
    required public init?(json: JSON) {
        self.fileUUID = FileInfo.fileUUIDKey <~~ json
        self.deviceUUID = FileInfo.deviceUUIDKey <~~ json
        self.mimeType = FileInfo.mimeTypeKey <~~ json
        self.deleted = FileInfo.deletedKey <~~ json
        
        self.appMetaDataVersion = Decoder.decode(int32ForKey: FileInfo.appMetaDataVersionKey)(json)

        self.fileVersion = Decoder.decode(int32ForKey: FileInfo.fileVersionKey)(json)
        self.fileSizeBytes = Decoder.decode(int64ForKey: FileInfo.fileSizeBytesKey)(json)
        
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
            FileInfo.appMetaDataVersionKey ~~> self.appMetaDataVersion,
            FileInfo.deletedKey ~~> self.deleted,
            FileInfo.fileVersionKey ~~> self.fileVersion,
            FileInfo.fileSizeBytesKey ~~> self.fileSizeBytes,
            Encoder.encode(dateForKey: FileInfo.creationDateKey, dateFormatter: dateFormatter)(self.creationDate),
            Encoder.encode(dateForKey: FileInfo.updateDateKey, dateFormatter: dateFormatter)(self.updateDate)
        ])
    }
}

