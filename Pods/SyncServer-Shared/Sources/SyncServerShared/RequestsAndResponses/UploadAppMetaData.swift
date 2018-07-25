//
//  UploadAppMetaData.swift
//  SyncServer-Shared
//
//  Created by Christopher G Prince on 3/23/18.
//

import Foundation
import Gloss

#if SERVER
import PerfectLib
import Kitura
#endif

public struct AppMetaData: Gloss.Encodable, Gloss.Decodable, Equatable {
    public static func ==(lhs: AppMetaData, rhs: AppMetaData) -> Bool {
        return lhs.version == rhs.version && lhs.contents == rhs.contents
    }
    
    public func toJSON() -> JSON? {
        if version == nil || contents == nil {
            return nil
        }
        
        return jsonify([
            AppMetaData.versionKey ~~> self.version,
            AppMetaData.contentsKey ~~> self.contents
        ])
    }
    
    public init(version: AppMetaDataVersionInt, contents: String) {
        self.version = version
        self.contents = contents
    }
    
    public init?(version: AppMetaDataVersionInt?, contents: String?) {
        if version == nil || contents == nil {
            return nil
        }
        
        self.version = version
        self.contents = contents
    }

    public init?(json: JSON) {
        version = Decoder.decode(int32ForKey: AppMetaData.versionKey)(json)
        contents = AppMetaData.contentsKey <~~ json
        
        if version == nil || contents == nil {
            return nil
        }
    }

    public static let contentsKey = "appMetaDataContents"
    public static let versionKey = "appMetaDataVersion"
    
    // Must be 0 (for new appMetaData) or N+1 where N is the current version of the appMetaData on the server. Each time you change the contents field and upload it, you must increment this version.
    public let version: AppMetaDataVersionInt!
    
    public let contents: String!
}

// Updating the app meta data using this request doesn't change the update date on the file.
public class UploadAppMetaDataRequest : NSObject, RequestMessage {
    // MARK: Properties for use in request message.
    
    // Assigned by client.
    public static let fileUUIDKey = "fileUUID"
    public var fileUUID:String!
    
    public var appMetaData:AppMetaData!
    
    // Overall version for files for the specific owning user; assigned by the server.
    public static let masterVersionKey = "masterVersion"
    public var masterVersion:MasterVersionInt!
    
    public var sharingGroupId: SharingGroupId!
    
    public func nonNilKeys() -> [String] {
        return [UploadAppMetaDataRequest.fileUUIDKey, UploadAppMetaDataRequest.masterVersionKey,
            ServerEndpoint.sharingGroupIdKey]
    }
    
    public func allKeys() -> [String] {
        // Not considering the AppMetaData values to be non-nil because of the way I'm checking for non-nil below. Checking for non-nil for these in [1] below.
        return self.nonNilKeys() + [AppMetaData.contentsKey, AppMetaData.versionKey]
    }
    
    public override init() {
        super.init()
    }
    
    public required init?(json: JSON) {
        super.init()
        
        self.fileUUID = UploadAppMetaDataRequest.fileUUIDKey <~~ json
        
        // Nested structures aren't working so well with `request.queryParameters`.
        self.appMetaData = AppMetaData(json: json)
        
        self.masterVersion = Decoder.decode(int64ForKey: UploadAppMetaDataRequest.masterVersionKey)(json)
        self.sharingGroupId = Decoder.decode(int64ForKey: ServerEndpoint.sharingGroupIdKey)(json)
        
#if SERVER
        if !nonNilKeysHaveValues(in: json) {
            return nil
        }
    
        // [1]
        if appMetaData?.contents == nil || appMetaData?.version == nil {
            return nil
        }
#endif

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
        var result = [
            UploadAppMetaDataRequest.fileUUIDKey ~~> self.fileUUID,
            UploadAppMetaDataRequest.masterVersionKey ~~> self.masterVersion,
            ServerEndpoint.sharingGroupIdKey ~~> self.sharingGroupId
        ]
        
        if let appMetaData = self.appMetaData?.toJSON() {
            result += [appMetaData]
        }
        
        return jsonify(result)
    }
}

public class UploadAppMetaDataResponse : ResponseMessage {
    public var responseType: ResponseType {
        return .json
    }
    
    // If the master version for the user on the server has been incremented, this key will be present in the response-- with the new value of the master version. The upload was not attempted in this case.
    public static let masterVersionUpdateKey = "masterVersionUpdate"
    public var masterVersionUpdate:MasterVersionInt?
    
    public required init?(json: JSON) {
        self.masterVersionUpdate = Decoder.decode(int64ForKey: UploadFileResponse.masterVersionUpdateKey)(json)
    }
    
    public convenience init?() {
        self.init(json:[:])
    }
    
    // MARK: - Serialization
    public func toJSON() -> JSON? {

        return jsonify([
            UploadFileResponse.masterVersionUpdateKey ~~> self.masterVersionUpdate,
        ])
    }
}

