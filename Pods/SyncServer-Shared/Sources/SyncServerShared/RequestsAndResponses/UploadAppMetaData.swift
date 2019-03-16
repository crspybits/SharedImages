//
//  UploadAppMetaData.swift
//  SyncServer-Shared
//
//  Created by Christopher G Prince on 3/23/18.
//

import Foundation
#if SERVER
import LoggerAPI
#endif

public struct AppMetaData: Codable, Equatable {
    private static let rootKey = "appMetaData"
    
    // Must be 0 (for new appMetaData) or N+1 where N is the current version of the appMetaData on the server. Each time you change the contents field and upload it, you must increment this version.
    public let version: AppMetaDataVersionInt
    private static let versionKey = "version"

    public let contents: String
    
    public static func ==(lhs: AppMetaData, rhs: AppMetaData) -> Bool {
        return lhs.version == rhs.version && lhs.contents == rhs.contents
    }

    public init(version: AppMetaDataVersionInt, contents: String) {
        self.version = version
        self.contents = contents
    }
    
    static func fromStringToDictionaryValue(dictionary: inout [String: Any]) {
        if let str = dictionary[rootKey] as? String,
            var appMetaDataDict = str.toJSONDictionary() {
            MessageDecoder.convert(key: versionKey, dictionary: &appMetaDataDict) {AppMetaDataVersionInt($0)}
            dictionary[rootKey] = appMetaDataDict
        }
    }
}

// Updating the app meta data using this request doesn't change the update date on the file.
public class UploadAppMetaDataRequest : RequestMessage {
    required public init() {}

    // MARK: Properties for use in request message.
    
    // Assigned by client.
    public var fileUUID:String!
    
    public var appMetaData:AppMetaData!
    private static let appMetaDataKey = "appMetaData"

    // Overall version for files for the specific owning user; assigned by the server.
    public var masterVersion:MasterVersionInt!
    private static let masterVersionKey = "masterVersion"
    
    public var sharingGroupUUID:String!
    
    public func valid() -> Bool {
        guard fileUUID != nil && masterVersion != nil && sharingGroupUUID != nil,
            let _ = NSUUID(uuidString: self.fileUUID) else {
            return false
        }
        
        return true
    }
    
    private static func customConversions(dictionary: [String: Any]) -> [String: Any] {
        var result = dictionary
        
        MessageDecoder.unescapeValues(dictionary: &result)
        AppMetaData.fromStringToDictionaryValue(dictionary: &result)
        
        // Unfortunate customization due to https://bugs.swift.org/browse/SR-5249
        MessageDecoder.convert(key: masterVersionKey, dictionary: &result) {MasterVersionInt($0)}

        return result
    }

    public static func decode(_ dictionary: [String: Any]) throws -> RequestMessage {
        return try MessageDecoder.decode(UploadAppMetaDataRequest.self, from: customConversions(dictionary: dictionary))
    }
    
    public func urlParameters() -> String? {
        guard var jsonDict = toDictionary else {
#if SERVER
            Log.error("Could not convert toJSON()!")
#endif
            return nil
        }
        
        // It's easier to decode JSON than a string encoded Dictionary.
        if let appMetaData = appMetaData {
            let encoder = JSONEncoder()
            guard let data = try? encoder.encode(appMetaData),
                let appMetaDataJSONString = String(data: data, encoding: .utf8) else {
                return nil
            }

            jsonDict[UploadAppMetaDataRequest.appMetaDataKey] = appMetaDataJSONString
        }

        return urlParameters(dictionary: jsonDict)
    }
}

public class UploadAppMetaDataResponse : ResponseMessage {
    required public init() {}

    public var responseType: ResponseType {
        return .json
    }
    
    // If the master version for the user on the server has been incremented, this key will be present in the response-- with the new value of the master version. The upload was not attempted in this case.
    public var masterVersionUpdate:MasterVersionInt?
    private static let masterVersionUpdateKey = "masterVersionUpdate"
    
    private static func customConversions(dictionary: [String: Any]) -> [String: Any] {
        var result = dictionary
        
        // Unfortunate customization due to https://bugs.swift.org/browse/SR-5249
        MessageDecoder.convert(key: masterVersionUpdateKey, dictionary: &result) {MasterVersionInt($0)}

        return result
    }

    public static func decode(_ dictionary: [String: Any]) throws -> UploadAppMetaDataResponse {
        return try MessageDecoder.decode(UploadAppMetaDataResponse.self, from: customConversions(dictionary: dictionary))
    }
}

