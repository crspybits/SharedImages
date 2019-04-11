//
//  GetUploads.swift
//  Server
//
//  Created by Christopher Prince on 2/18/17.
//
//

import Foundation

// Request an index of file uploads (UploadFile) and upload deletions (UploadDeleletion) -- queries the meta data on the sync server. The uploads are specific both to the user and the deviceUUID of the user.

public class GetUploadsRequest : RequestMessage {
    required public init() {}

    // MARK: Properties for use in request message.

    public var sharingGroupUUID: String!

    public func valid() -> Bool {
        guard sharingGroupUUID != nil,
            let _ = UUID(uuidString: sharingGroupUUID) else {
            return false
        }
        
        return true
    }
    
    public static func decode(_ dictionary: [String: Any]) throws -> RequestMessage {
        return try MessageDecoder.decode(GetUploadsRequest.self, from: dictionary)
    }
}

public class GetUploadsResponse : ResponseMessage {
    required public init() {}

    public var responseType: ResponseType {
        return .json
    }
    
    // FileInfo objects don't contain `cloudStorageType`.
    public var uploads:[FileInfo]?
    
    public static func decode(_ dictionary: [String: Any]) throws -> GetUploadsResponse {
        return try MessageDecoder.decode(GetUploadsResponse.self, from: dictionary)
    }
}
