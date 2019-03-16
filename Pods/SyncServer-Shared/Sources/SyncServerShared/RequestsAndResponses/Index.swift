//
//  Index.swift
//  Server
//
//  Created by Christopher Prince on 1/28/17.
//
//

import Foundation

// Returns a list of all sharing groups that the user is a member of.
// And optionally request an index of all files that have been uploaded with UploadFile and committed using DoneUploads for the sharing group -- queries the meta data on the sync server.
// When a sharing group has been deleted, you cannot request a file index for that sharing group. Similarly, if a user is not a member of a sharing group, you cannot request a file index for that sharing group.

public class IndexRequest : RequestMessage {
    required public init() {}

#if DEBUG
    // Give a time value in seconds -- the server for sleep to test failure of API calls.
    public var testServerSleep:Int32?
#endif

    // Give this if you want the index of files for a sharing group.
    public var sharingGroupUUID: String?
    
    public func valid() -> Bool {
        return true
    }
    
    public static func decode(_ dictionary: [String: Any]) throws -> RequestMessage {
        return try MessageDecoder.decode(IndexRequest.self, from: dictionary)
    }
}

public class IndexResponse : ResponseMessage {
    required public init() {}

    public var responseType: ResponseType {
        return .json
    }
    
    // The following two are provided iff you gave a sharing group id in the request.
    
    // The master version for the requested sharing group.
    public var masterVersion:MasterVersionInt?
    
    // The files in the requested sharing group.
    public var fileIndex:[FileInfo]?
    
    // The sharing groups in which this user is a member.
    public var sharingGroups:[SharingGroup]!
    
    public static func decode(_ dictionary: [String: Any]) throws -> IndexResponse {
        return try MessageDecoder.decode(IndexResponse.self, from: dictionary)
    }
}

