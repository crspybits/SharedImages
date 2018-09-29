//
//  DownloadAppMetaData.swift
//  SyncServer-Shared
//
//  Created by Christopher G Prince on 3/23/18.
//

import Foundation
import Gloss

#if SERVER
import Kitura
#endif

public class DownloadAppMetaDataRequest : NSObject, RequestMessage {
    // MARK: Properties for use in request message.
    
    public static let fileUUIDKey = "fileUUID"
    public var fileUUID:String!
    
    // This must indicate the current version in the FileIndex. Not allowing this to be nil because that would mean the appMetaData on the server would be nil, and what's the point of asking for that?
    public static let appMetaDataVersionKey = "appMetaDataVersion"
    public var appMetaDataVersion:AppMetaDataVersionInt!
    
    // Overall version for files for the specific user; assigned by the server.
    public static let masterVersionKey = "masterVersion"
    public var masterVersion:MasterVersionInt!
    
    public var sharingGroupUUID: String!
    
    public func nonNilKeys() -> [String] {
        return [DownloadAppMetaDataRequest.fileUUIDKey, DownloadAppMetaDataRequest.appMetaDataVersionKey, DownloadAppMetaDataRequest.masterVersionKey,
            ServerEndpoint.sharingGroupUUIDKey]
    }
    
    public func allKeys() -> [String] {
        return self.nonNilKeys()
    }
    
    public required init?(json: JSON) {
        super.init()
        
        self.fileUUID = DownloadAppMetaDataRequest.fileUUIDKey <~~ json
        self.masterVersion = Decoder.decode(int64ForKey: DownloadAppMetaDataRequest.masterVersionKey)(json)
        self.appMetaDataVersion = Decoder.decode(int32ForKey: DownloadAppMetaDataRequest.appMetaDataVersionKey)(json)
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
            DownloadAppMetaDataRequest.fileUUIDKey ~~> self.fileUUID,
            DownloadAppMetaDataRequest.masterVersionKey ~~> self.masterVersion,
            DownloadAppMetaDataRequest.appMetaDataVersionKey ~~> self.appMetaDataVersion,
            ServerEndpoint.sharingGroupUUIDKey ~~> self.sharingGroupUUID
        ])
    }
}

public class DownloadAppMetaDataResponse : ResponseMessage {
    public var responseType: ResponseType {
        return .json
    }
    
    // Just the appMetaData contents.
    public static let appMetaDataKey = "appMetaData"
    public var appMetaData:String?
    
    // If the master version for the user on the server has been incremented, this key will be present in the response-- with the new value of the master version. The download was not attempted in this case.
    public static let masterVersionUpdateKey = "masterVersionUpdate"
    public var masterVersionUpdate:MasterVersionInt?
    
    public required init?(json: JSON) {
        self.masterVersionUpdate = Decoder.decode(int64ForKey: DownloadAppMetaDataResponse.masterVersionUpdateKey)(json)
        self.appMetaData = DownloadAppMetaDataResponse.appMetaDataKey <~~ json
    }
    
    public convenience init?() {
        self.init(json:[:])
    }
    
    // MARK: - Serialization
    public func toJSON() -> JSON? {
        return jsonify([
            DownloadAppMetaDataResponse.masterVersionUpdateKey ~~> self.masterVersionUpdate,
            DownloadAppMetaDataResponse.appMetaDataKey ~~> self.appMetaData
        ])
    }
}
