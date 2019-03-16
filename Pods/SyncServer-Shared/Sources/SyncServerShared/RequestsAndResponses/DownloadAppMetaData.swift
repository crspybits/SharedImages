//
//  DownloadAppMetaData.swift
//  SyncServer-Shared
//
//  Created by Christopher G Prince on 3/23/18.
//

import Foundation

public class DownloadAppMetaDataRequest : RequestMessage {
    required public init() {}

    // MARK: Properties for use in request message.
    
    public var fileUUID:String!
    
    // This must indicate the current version in the FileIndex. Not allowing this to be nil because that would mean the appMetaData on the server would be nil, and what's the point of asking for that?
    public var appMetaDataVersion:AppMetaDataVersionInt!
    private static let appMetaDataVersionKey = "appMetaDataVersion"
    
    // Overall version for files for the specific user; assigned by the server.
    public var masterVersion:MasterVersionInt!
    private static let masterVersionKey = "masterVersion"

    public var sharingGroupUUID: String!
    
    public func valid() -> Bool {
        return fileUUID != nil && appMetaDataVersion != nil && masterVersion != nil && sharingGroupUUID != nil
    }
    
    private static func customConversions(dictionary: [String: Any]) -> [String: Any] {
        var result = dictionary
        
        // Unfortunate customization due to https://bugs.swift.org/browse/SR-5249
        MessageDecoder.convert(key: masterVersionKey, dictionary: &result) {MasterVersionInt($0)}
        MessageDecoder.convert(key: appMetaDataVersionKey, dictionary: &result) {AppMetaDataVersionInt($0)}

        return result
    }

    public static func decode(_ dictionary: [String: Any]) throws -> RequestMessage {
        return try MessageDecoder.decode(DownloadAppMetaDataRequest.self, from: customConversions(dictionary: dictionary))
    }
}

public class DownloadAppMetaDataResponse : ResponseMessage {
    required public init() {}

    public var responseType: ResponseType {
        return .json
    }
    
    // Just the appMetaData contents.
    public var appMetaData:String?
    
    // If the master version for the user on the server has been incremented, this key will be present in the response-- with the new value of the master version. The download was not attempted in this case.
    public var masterVersionUpdate:MasterVersionInt?
    private static let masterVersionUpdateKey = "masterVersionUpdate"
    
    private static func customConversions(dictionary: [String: Any]) -> [String: Any] {
        var result = dictionary
        
        // Unfortunate customization due to https://bugs.swift.org/browse/SR-5249
        MessageDecoder.convert(key: masterVersionUpdateKey, dictionary: &result) {MasterVersionInt($0)}

        return result
    }

    public static func decode(_ dictionary: [String: Any]) throws -> DownloadAppMetaDataResponse {
        return try MessageDecoder.decode(DownloadAppMetaDataResponse.self, from: customConversions(dictionary: dictionary))
    }
}
