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
    
    public var sharingGroupUUID:String!
    
    // This must indicate the current version of the app meta data for the file in the FileIndex (or nil if there is none yet).
    public static let appMetaDataVersionKey = "appMetaDataVersion"
    public var appMetaDataVersion:AppMetaDataVersionInt?
    
    // Overall version for files for the specific user; assigned by the server.
    public static let masterVersionKey = "masterVersion"
    public var masterVersion:MasterVersionInt!
    
    public func nonNilKeys() -> [String] {
        return [DownloadFileRequest.fileUUIDKey, DownloadFileRequest.fileVersionKey, DownloadFileRequest.masterVersionKey,
            ServerEndpoint.sharingGroupUUIDKey]
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
        self.sharingGroupUUID = ServerEndpoint.sharingGroupUUIDKey <~~ json
        
        if !self.nonNilKeysHaveValues(in: json) {
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
            DownloadFileRequest.appMetaDataVersionKey ~~> self.appMetaDataVersion,
            ServerEndpoint.sharingGroupUUIDKey ~~> self.sharingGroupUUID
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
    
    // This can be used by a client to know how to compute the checksum if they upload another version of this file.
    public static let cloudStorageTypeKey = "cloudStorageType"
    public var cloudStorageType: String!

    // The check sum for the file currently stored in cloud storage. The specific meaning of this value depends on the specific cloud storage system. See `cloudStorageType`. This can be used by clients to assess if there was an error in transmitting the file contents across the network. i.e., does this checksum match what is computed by the client after the file is downloaded?
    public static let checkSumKey = "checkSum"
    public var checkSum:String!
    
    // Did the contents of the file change while it was "at rest" in cloud storage? e.g., a user changed their file directly?
    public static let contentsChangedKey = "contentsChanged"
    public var contentsChanged:Bool!
    
    // If the master version for the user on the server has been incremented, this key will be present in the response-- with the new value of the master version. The download was not attempted in this case.
    public static let masterVersionUpdateKey = "masterVersionUpdate"
    public var masterVersionUpdate:MasterVersionInt?
    
    // The file was gone and could not be downloaded. The string gives the GoneReason if non-nil, and the data, contentsChanged, and checkSum fields are not given.
    public static let goneKey = "gone"
    public var gone: String?
    
    public required init?(json: JSON) {
        self.masterVersionUpdate = Decoder.decode(int64ForKey: DownloadFileResponse.masterVersionUpdateKey)(json)
        self.appMetaData = DownloadFileResponse.appMetaDataKey <~~ json
        self.cloudStorageType = DownloadFileResponse.cloudStorageTypeKey <~~ json
        self.checkSum = DownloadFileResponse.checkSumKey <~~ json
        self.contentsChanged = DownloadFileResponse.contentsChangedKey <~~ json
        self.gone = DownloadFileResponse.goneKey <~~ json
    }
    
    public convenience init?() {
        self.init(json:[:])
    }
    
    // MARK: - Serialization
    public func toJSON() -> JSON? {
        return jsonify([
            DownloadFileResponse.masterVersionUpdateKey ~~> self.masterVersionUpdate,
            DownloadFileResponse.appMetaDataKey ~~> self.appMetaData,
            DownloadFileResponse.checkSumKey ~~> self.checkSum,
            DownloadFileResponse.cloudStorageTypeKey ~~> self.cloudStorageType,
            DownloadFileResponse.contentsChangedKey ~~> self.contentsChanged,
            DownloadFileResponse.goneKey ~~> self.gone
        ])
    }
}
