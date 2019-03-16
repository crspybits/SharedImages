//
//  DoneUploads.swift
//  Server
//
//  Created by Christopher Prince on 1/21/17.
//
//

import Foundation

// As part of normal processing, increments the current master version for the sharing group. Calling DoneUploads a second time (immediately after the first) results in 0 files being transferred. i.e., `numberUploadsTransferred` will be 0 for the result of the second operation. This is not considered an error, and the masterVersion is still incremented in this case.
// This operation optionally enables a sharing group update. This provides a means for the sharing group update to not to be queued on the server.
// And it optionally allows for sending a push notification to members of the sharing group.
public class DoneUploadsRequest : RequestMessage, MasterVersionUpdateRequest {
    required public init() {}

    // MARK: Properties for use in request message.
    
    // Overall version for files for the specific sharing group; assigned by the server.
    public var masterVersion:MasterVersionInt!
    static let masterVersionKey = "masterVersion"
    
    public var sharingGroupUUID: String!
    
#if DEBUG
    // Give a time value in seconds -- after the lock is obtained, the server for sleep for this lock to test locking operation.
    public var testLockSync:Int32?
    static let testLockSyncKey = "testLockSync"
#endif

    // Optionally perform a sharing group update-- i.e., change the sharing group's name as part of DoneUploads.
    public var sharingGroupName: String?
    
    // Optionally, send a push notification to all members of the sharing group (except for the sender) on a successful DoneUploads. The text of a message for a push notification is application specific and so needs to come from the client.
    public var pushNotificationMessage: String?
    
    public func valid() -> Bool {
        return sharingGroupUUID != nil && masterVersion != nil
    }
    
    private static func customConversions(dictionary: [String: Any]) -> [String: Any] {
        var result = dictionary
        
        MessageDecoder.unescapeValues(dictionary: &result)
 
        MessageDecoder.convert(key: masterVersionKey, dictionary: &result) {MasterVersionInt($0)}
#if DEBUG
        MessageDecoder.convert(key: testLockSyncKey, dictionary: &result) {Int32($0)}
#endif
        return result
    }

    public static func decode(_ dictionary: [String: Any]) throws -> RequestMessage {
        return try MessageDecoder.decode(DoneUploadsRequest.self, from: customConversions(dictionary: dictionary))
    }
}

public class DoneUploadsResponse : ResponseMessage, MasterVersionUpdateResponse {
    required public init() {}

    public var responseType: ResponseType {
        return .json
    }
    
    // There are two possible non-error responses to DoneUploads:
    
    // 1) On successful operation, this gives the number of uploads entries transferred to the FileIndex.
    public var numberUploadsTransferred:Int32?
    private static let numberUploadsTransferredKey = "numberUploadsTransferred"
    
    // 2) If the master version for the sharing group on the server had been previously incremented to a value different than the masterVersion value in the request, this key will be present in the response-- with the new value of the master version. The doneUploads operation was not attempted in this case.
    public var masterVersionUpdate:MasterVersionInt?
    private static let masterVersionUpdateKey = "masterVersionUpdate"

    // If present, this reports an error situation on the server. Can only occur if there were pending UploadDeletion's.
    public var numberDeletionErrors:Int32?
    private static let numberDeletionErrorsKey = "numberDeletionErrors"

    private static func customConversions(dictionary: [String: Any]) -> [String: Any] {
        var result = dictionary
        
        MessageDecoder.convert(key: numberUploadsTransferredKey, dictionary: &result) {Int32($0)}
        MessageDecoder.convert(key: masterVersionUpdateKey, dictionary: &result) {MasterVersionInt($0)}
        MessageDecoder.convert(key: numberDeletionErrorsKey, dictionary: &result) {Int32($0)}
        
        return result
    }

    public static func decode(_ dictionary: [String: Any]) throws -> DoneUploadsResponse {
        return try MessageDecoder.decode(DoneUploadsResponse.self, from: customConversions(dictionary: dictionary))
    }
}
