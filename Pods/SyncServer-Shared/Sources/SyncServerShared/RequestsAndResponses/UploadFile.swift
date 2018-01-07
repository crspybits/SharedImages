//
//  UploadFile.swift
//  Server
//
//  Created by Christopher Prince on 1/15/17.
//
//

import Foundation
import Gloss

#if SERVER
import PerfectLib
import Kitura
#endif

/* If an attempt is made to upload the same file more than once, the second (or third etc.) attempts don't actually upload the file to cloud storage-- if we have an entry in the Uploads repository. The effect from the POV of the caller is same as if the file was uploaded. We don't consider this an error to help in error recovery.
(We don't actually upload the file more than once to the cloud service because Google Drive doesn't play well with uploading the same named file more than once, and to help in error recovery, plus the design of the server only makes an Uploads entry if we have successfully uploaded the file to the cloud service.)
*/
public class UploadFileRequest : NSObject, RequestMessage, Filenaming {
    // MARK: Properties for use in request message.
    
    // Assigned by client.
    public static let fileUUIDKey = "fileUUID"
    public var fileUUID:String!
    
    public static let mimeTypeKey = "mimeType"
    public var mimeType:String!
    
    // A root-level folder in the cloud file service. This is only used by some of the cloud file servces. E.g., Google Drive. It's not used by Dropbox.
    public static let cloudFolderNameKey = "cloudFolderName"
    public var cloudFolderName:String?
    
    public static let appMetaDataKey = "appMetaData"
    public var appMetaData:String!
    
    public static let fileVersionKey = "fileVersion"
    public var fileVersion:FileVersionInt!
    
    // Overall version for files for the specific user; assigned by the server.
    public static let masterVersionKey = "masterVersion"
    public var masterVersion:MasterVersionInt!
    
    // MARK: Properties NOT used in the request message.
    
    public var data = Data()
    public var sizeOfDataInBytes:Int!
    
    public func nonNilKeys() -> [String] {
        return [UploadFileRequest.fileUUIDKey, UploadFileRequest.mimeTypeKey, UploadFileRequest.fileVersionKey, UploadFileRequest.masterVersionKey]
    }
    
    public func allKeys() -> [String] {
        return self.nonNilKeys() + [UploadFileRequest.appMetaDataKey, UploadFileRequest.cloudFolderNameKey]
    }
    
    public required init?(json: JSON) {
        super.init()
        
        self.fileUUID = UploadFileRequest.fileUUIDKey <~~ json
        self.mimeType = UploadFileRequest.mimeTypeKey <~~ json
        self.cloudFolderName = UploadFileRequest.cloudFolderNameKey <~~ json
        self.fileVersion = Decoder.decode(int32ForKey: UploadFileRequest.fileVersionKey)(json)
        self.masterVersion = Decoder.decode(int64ForKey: UploadFileRequest.masterVersionKey)(json)
        self.appMetaData = UploadFileRequest.appMetaDataKey <~~ json
                
#if SERVER
        if !self.propertiesHaveValues(propertyNames: self.nonNilKeys()) {
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
        do {
            // TODO: *4* Eventually this needs to be converted into stream processing where a stream from client is passed along to Google Drive or some other cloud service-- so not all of the file has to be read onto the server. For big files this will crash the server.
            self.sizeOfDataInBytes = try request.read(into: &self.data)
        } catch (let error) {
            Log.error(message: "Could not upload file: \(error)")
            return nil
        }
    }
#endif
    
    public func toJSON() -> JSON? {
        return jsonify([
            UploadFileRequest.fileUUIDKey ~~> self.fileUUID,
            UploadFileRequest.mimeTypeKey ~~> self.mimeType,
            UploadFileRequest.cloudFolderNameKey ~~> self.cloudFolderName,
            UploadFileRequest.fileVersionKey ~~> self.fileVersion,
            UploadFileRequest.masterVersionKey ~~> self.masterVersion,
            UploadFileRequest.appMetaDataKey ~~> self.appMetaData
        ])
    }
}

public class UploadFileResponse : ResponseMessage {
    public var responseType: ResponseType {
        return .header
    }
    
    // On a successful upload, the following fields will be present in the response.
    public static let sizeKey = "sizeInBytes"
    public var size:Int64?
    
    // 12/27/17; These two were added to the response. See https://github.com/crspybits/SharedImages/issues/44
    // This is the actual date/time of creation of the file on the server.
    public static let creationDateKey = "creationDate"
    public var creationDate: Date?
 
    // This is the actual date/time of update of the file on the server.
    public static let updateDateKey = "updateDate"
    public var updateDate: Date?
    
    // If the master version for the user on the server has been incremented, this key will be present in the response-- with the new value of the master version. The upload was not attempted in this case.
    public static let masterVersionUpdateKey = "masterVersionUpdate"
    public var masterVersionUpdate:MasterVersionInt?
    
    public required init?(json: JSON) {
        self.size = Decoder.decode(int64ForKey: UploadFileResponse.sizeKey)(json)
        self.masterVersionUpdate = Decoder.decode(int64ForKey: UploadFileResponse.masterVersionUpdateKey)(json)
        
        let dateFormatter = DateExtras.getDateFormatter(format: .DATETIME)
        self.creationDate = Decoder.decode(dateForKey: UploadFileResponse.creationDateKey, dateFormatter: dateFormatter)(json)
        self.updateDate = Decoder.decode(dateForKey: UploadFileResponse.updateDateKey, dateFormatter: dateFormatter)(json)
    }
    
    public convenience init?() {
        self.init(json:[:])
    }
    
    // MARK: - Serialization
    public func toJSON() -> JSON? {
        let dateFormatter = DateExtras.getDateFormatter(format: .DATETIME)

        return jsonify([
            UploadFileResponse.sizeKey ~~> self.size,
            UploadFileResponse.masterVersionUpdateKey ~~> self.masterVersionUpdate,
            Encoder.encode(dateForKey: UploadFileResponse.creationDateKey, dateFormatter: dateFormatter)(self.creationDate),
            Encoder.encode(dateForKey: UploadFileResponse.updateDateKey, dateFormatter: dateFormatter)(self.updateDate)
        ])
    }
}
