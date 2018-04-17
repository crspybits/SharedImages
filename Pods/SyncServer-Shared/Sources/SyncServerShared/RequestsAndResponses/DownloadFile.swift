//
//  DownloadFile.swift
//  Server
//
//  Created by Christopher Prince on 1/29/17.
//
//

import Foundation
import Gloss

#if SERVER
import Kitura
#endif

public class DownloadFileRequest : NSObject, RequestMessage {
    // MARK: Properties for use in request message.
    
    public static let fileUUIDKey = "fileUUID"
    public var fileUUID:String!
    
    // This must indicate the current version of the file in the FileIndex.
    public static let fileVersionKey = "fileVersion"
    public var fileVersion:FileVersionInt!
    
    // This must indicate the current version of the app meta data for the file in the FileIndex (or nil if there is none yet).
    public static let appMetaDataVersionKey = "appMetaDataVersion"
    public var appMetaDataVersion:AppMetaDataVersionInt?
    
    // Overall version for files for the specific user; assigned by the server.
    public static let masterVersionKey = "masterVersion"
    public var masterVersion:MasterVersionInt!
    
    public func nonNilKeys() -> [String] {
        return [DownloadFileRequest.fileUUIDKey, DownloadFileRequest.fileVersionKey, DownloadFileRequest.masterVersionKey]
    }
    
    public func allKeys() -> [String] {
        return self.nonNilKeys() + [DownloadFileRequest.appMetaDataVersionKey]
    }
    
    public required init?(json: JSON) {
        super.init()
        
        self.fileUUID = DownloadFileRequest.fileUUIDKey <~~ json
        
        self.masterVersion = Decoder.decode(int64ForKey: DownloadFileRequest.masterVersionKey)(json)
        self.fileVersion = Decoder.decode(int32ForKey: DownloadFileRequest.fileVersionKey)(json)
        self.appMetaDataVersion = Decoder.decode(int32ForKey: DownloadFileRequest.appMetaDataVersionKey)(json)
        
        if !self.propertiesHaveValues(propertyNames: self.nonNilKeys()) {
            return nil
        }
        
        guard let _ = NSUUID(uuidString: self.fileUUID) else {
            return nil
        }
    }
    
#if SERVER
    public required convenience init?(request: RouterRequest) {
        self.init(json: request.queryParameters)
    }
#endif
    
    public func toJSON() -> JSON? {
        return jsonify([
            DownloadFileRequest.fileUUIDKey ~~> self.fileUUID,
            DownloadFileRequest.masterVersionKey ~~> self.masterVersion,
            DownloadFileRequest.fileVersionKey ~~> self.fileVersion,
            DownloadFileRequest.appMetaDataVersionKey ~~> self.appMetaDataVersion
        ])
    }
}

public class DownloadFileResponse : ResponseMessage {
    public var responseType: ResponseType {
        return .data(data: data)
    }
    
    public static let appMetaDataKey = "appMetaData"
    public var appMetaData:String?
    
    public var data:Data?
    
    public static let fileSizeBytesKey = "fileSizeBytes"
    public var fileSizeBytes:Int64?
    
    // If the master version for the user on the server has been incremented, this key will be present in the response-- with the new value of the master version. The download was not attempted in this case.
    public static let masterVersionUpdateKey = "masterVersionUpdate"
    public var masterVersionUpdate:MasterVersionInt?
    
    public required init?(json: JSON) {
        self.masterVersionUpdate = Decoder.decode(int64ForKey: DownloadFileResponse.masterVersionUpdateKey)(json)
        self.appMetaData = DownloadFileResponse.appMetaDataKey <~~ json
        self.fileSizeBytes = Decoder.decode(int64ForKey: DownloadFileResponse.fileSizeBytesKey)(json)
    }
    
    public convenience init?() {
        self.init(json:[:])
    }
    
    // MARK: - Serialization
    public func toJSON() -> JSON? {
        return jsonify([
            DownloadFileResponse.masterVersionUpdateKey ~~> self.masterVersionUpdate,
            DownloadFileResponse.appMetaDataKey ~~> self.appMetaData,
            DownloadFileResponse.fileSizeBytesKey ~~> self.fileSizeBytes
        ])
    }
}
