//
//  DeleteFile.swift
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

// This places a deletion request in the Upload table on the server. A DoneUploads request is subsequently required to actually perform the deletion in cloud storage.
// An upload deletion can be repeated for the same file: This doesn't cause an error and doesn't duplicate rows in the Upload table.

public class UploadDeletionRequest : NSObject, RequestMessage, Filenaming {
    // The use of the Filenaming protocol here is to support the DEBUG `actualDeletion` parameter.
    
    // MARK: Properties for use in request message.
    
    public static let fileUUIDKey = "fileUUID"
    public var fileUUID:String!
    
    // This must indicate the current version of the file in the FileIndex.
    public static let fileVersionKey = "fileVersion"
    public var fileVersion:FileVersionInt!
    
    // Overall version for files for the specific user; assigned by the server.
    public static let masterVersionKey = "masterVersion"
    public var masterVersion:MasterVersionInt!
    
    public var sharingGroupId: SharingGroupId!

#if DEBUG
    // Enable the client to actually delete files-- for testing purposes. The UploadDeletionRequest will not queue the request, but instead deletes from both the FileIndex and from cloud storage.
    public static let actualDeletionKey = "actualDeletion"
    public var actualDeletion:Int32? // Should be 0 or non-0; I haven't been able to get Bool to work with Gloss
#endif
    
    public func nonNilKeys() -> [String] {
        return [UploadDeletionRequest.fileUUIDKey, UploadDeletionRequest.fileVersionKey, UploadDeletionRequest.masterVersionKey,
            ServerEndpoint.sharingGroupIdKey]
    }
    
    public func allKeys() -> [String] {
        var keys = [String]()
        keys += self.nonNilKeys()
#if DEBUG
        keys += [UploadDeletionRequest.actualDeletionKey]
#endif
        return keys
    }
    
    public required init?(json: JSON) {
        super.init()
        
        self.fileUUID = UploadDeletionRequest.fileUUIDKey <~~ json
        
        self.masterVersion = Decoder.decode(int64ForKey: UploadDeletionRequest.masterVersionKey)(json)
        self.fileVersion = Decoder.decode(int32ForKey: UploadDeletionRequest.fileVersionKey)(json)
        self.sharingGroupId = Decoder.decode(int64ForKey: ServerEndpoint.sharingGroupIdKey)(json)
        
#if DEBUG
        self.actualDeletion = Decoder.decode(int32ForKey:  UploadDeletionRequest.actualDeletionKey)(json)
#endif
        
        if !nonNilKeysHaveValues(in: json) {
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
        var param:[JSON?] = []
        
        param += [
            UploadDeletionRequest.fileUUIDKey ~~> self.fileUUID,
            UploadDeletionRequest.masterVersionKey ~~> self.masterVersion,
            UploadDeletionRequest.fileVersionKey ~~> self.fileVersion,
            ServerEndpoint.sharingGroupIdKey ~~> self.sharingGroupId
        ]
        
#if DEBUG
        param += [
            UploadDeletionRequest.actualDeletionKey ~~> self.actualDeletion
        ]
#endif
        
        return jsonify(param)
    }
}

public class UploadDeletionResponse : ResponseMessage {
    public var responseType: ResponseType {
        return .json
    }
    
    // If the master version for the user on the server has been incremented, this key will be present in the response-- with the new value of the master version. The upload deletion was not attempted in this case.
    public static let masterVersionUpdateKey = "masterVersionUpdate"
    public var masterVersionUpdate:Int64?
    
    public required init?(json: JSON) {
        self.masterVersionUpdate = Decoder.decode(int64ForKey:  UploadDeletionResponse.masterVersionUpdateKey)(json)        
    }
    
    public convenience init?() {
        self.init(json:[:])
    }
    
    // MARK: - Serialization
    public func toJSON() -> JSON? {
        return jsonify([
            UploadDeletionResponse.masterVersionUpdateKey ~~> self.masterVersionUpdate
        ])
    }
}
