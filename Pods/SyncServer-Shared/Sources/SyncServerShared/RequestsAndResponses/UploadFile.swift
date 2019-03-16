//
//  UploadFile.swift
//  Server
//
//  Created by Christopher Prince on 1/15/17.
//
//

import Foundation

#if SERVER
import Kitura
import LoggerAPI
#endif

/* If an attempt is made to upload the same file/version more than once, the second (or third etc.) attempts don't actually upload the file to cloud storage-- if we have an entry in the Uploads repository. The effect from the POV of the caller is same as if the file was uploaded. We don't consider this an error to help in error recovery.
(We don't actually upload the file more than once to the cloud service because, for example, Google Drive doesn't play well with uploading the same named file more than once, and to help in error recovery, plus the design of the server only makes an Uploads entry if we have successfully uploaded the file to the cloud service.)
*/
public class UploadFileRequest : RequestMessage, Filenaming {
    required public init() {}

    // MARK: Properties for use in request message.
    
    // Assigned by client.
    public var fileUUID:String!
    
    // If given, must be with version 0 of a file. Cannot be non-nil after version 0.
    public var fileGroupUUID:String?
    
    public var mimeType:String!
    
    // If a file is already on the server, and you are uploading a new version, simply setting the appMetaData contents to nil will not reset the appMetaData on the server. It will just ignore the nil field and leave the appMetaData as it was on the last version of the file. To reset the appMetaData, explicitly set its contents to the empty string "".
    // Set this to nil if you are not updating the app meta data.
    public var appMetaData:AppMetaData?
    
    // Must be 0 (for a new file) or N+1 where N is the current version of the file on the server.
    public var fileVersion:FileVersionInt!
    
    // Typically this will remain false (or nil). Give it as true only when doing conflict resolution and the client indicates it wants to undelete a file because it's overriding a download deletion with its own file upload.
    public var undeleteServerFile:Bool?

    // Overall version for files for the specific owning user; assigned by the server.
    public var masterVersion:MasterVersionInt!

    public var sharingGroupUUID: String!
    
    // The check sum for the file on the client *prior* to the upload. The specific meaning of this value depends on the specific cloud storage system. See `cloudStorageType`.
    public var checkSum:String!
    
    // MARK: Properties NOT used in the request message.
    
    public var data:Data!
    public var sizeOfDataInBytes:Int!
    
    // Eliminate data and sizeOfDataIn bytes from Codable coding
    // See also https://stackoverflow.com/questions/44655562/how-to-exclude-properties-from-swift-4s-codable
    private enum CodingKeys: String, CodingKey {
        case fileUUID
        case fileGroupUUID
        case mimeType
        case appMetaData
        case fileVersion
        case undeleteServerFile
        case masterVersion
        case sharingGroupUUID
        case checkSum
    }
    
    public func valid() -> Bool {
        guard fileUUID != nil && mimeType != nil && fileVersion != nil && masterVersion != nil && sharingGroupUUID != nil && checkSum != nil,
            let _ = NSUUID(uuidString: self.fileUUID),
            let _ = NSUUID(uuidString: self.sharingGroupUUID) else {
            return false
        }
        
        return true
    }

#if SERVER
    public func setup(request: RouterRequest) throws {
        var data = Data()
        sizeOfDataInBytes = try request.read(into: &data)
        self.data = data
    }
#endif

    private static func customConversions(dictionary: [String: Any]) -> [String: Any] {
        var result = dictionary
        
        MessageDecoder.unescapeValues(dictionary: &result)
        AppMetaData.fromStringToDictionaryValue(dictionary: &result)
        
        // Unfortunate customization due to https://bugs.swift.org/browse/SR-5249
        MessageDecoder.convert(key: UploadFileRequest.CodingKeys.fileVersion.rawValue, dictionary: &result) {FileVersionInt($0)}
        MessageDecoder.convertBool(key: UploadFileRequest.CodingKeys.undeleteServerFile.rawValue, dictionary: &result)
        MessageDecoder.convert(key: UploadFileRequest.CodingKeys.masterVersion.rawValue, dictionary: &result) {MasterVersionInt($0)}
        return result
    }

    public static func decode(_ dictionary: [String: Any]) throws -> RequestMessage {
        return try MessageDecoder.decode(UploadFileRequest.self, from: customConversions(dictionary: dictionary))
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

            jsonDict[UploadFileRequest.CodingKeys.appMetaData.rawValue] = appMetaDataJSONString
        }

        return urlParameters(dictionary: jsonDict)
    }
}

public class UploadFileResponse : ResponseMessage {
    required public init() {}

    public var responseType: ResponseType {
        return .header
    }
    
    // On a successful upload, the following fields will be present in the response.
    
    // 12/27/17; These two were added to the response. See https://github.com/crspybits/SharedImages/issues/44
    // This is the actual date/time of creation of the file on the server.
    public var creationDate: Date?
 
    // This is the actual date/time of update of the file on the server.
    public var updateDate: Date?
    
    // If the master version for the user on the server has been incremented, this key will be present in the response-- with the new value of the master version. The upload was not attempted in this case.
    public var masterVersionUpdate:MasterVersionInt?
    private static let masterVersionUpdateKey = "masterVersionUpdate"
    
    // Unfortunate customization due to https://bugs.swift.org/browse/SR-5249
    private static func customConversions(dictionary: [String: Any]) -> [String: Any] {
        var result = dictionary
        MessageDecoder.convert(key: masterVersionUpdateKey, dictionary: &result) {MasterVersionInt($0)}
        return result
    }
    
    public static func decode(_ dictionary: [String: Any]) throws -> UploadFileResponse {
        return try MessageDecoder.decode(UploadFileResponse.self, from: customConversions(dictionary: dictionary))
    }
}
