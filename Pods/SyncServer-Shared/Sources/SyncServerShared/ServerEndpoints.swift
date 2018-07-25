//
//  ServerEndpoints.swift
//  SyncServer-Shared
//
//  Created by Christopher G Prince on 6/21/18.
//

import Foundation

public struct ServerEndpoint {
    public let pathName:String // Doesn't have preceding "/"
    public let method:ServerHTTPMethod
    public let authenticationLevel:AuthenticationLevel
    
    // Does the user have the mimimum required permissions to perform the endpoint action?
    public let minPermission:Permission!
    
    // This specifies the need for a short duration lock on the operation. Only endpoints that have request messages that include a sharingGroupId can set this to true.
    public static let sharingGroupIdKey = "sharingGroupId"
    public let needsLock:Bool
    
    // Don't put a trailing "/" on the pathName.
    public init(_ pathName:String, method:ServerHTTPMethod, authenticationLevel:AuthenticationLevel = .secondary, needsLock:Bool = false, minPermission: Permission = .read) {

        assert(pathName.count > 0 && pathName.last != "/")
        
        self.pathName = pathName
        self.method = method
        self.authenticationLevel = authenticationLevel
        self.needsLock = needsLock
        self.minPermission = minPermission
    }
    
    public var path:String { // With prefix "/"
        return "/" + pathName
    }
    
    public var pathWithSuffixSlash:String { // With prefix "/" and suffix "/"
        return path + "/"
    }
}

/* When adding an endpoint:
    a) add it as a `public static let`
    b) add it in the `all` list in the `init`, and
    c) add it into ServerRoutes.swift
*/
public class ServerEndpoints {
    public private(set) var all = [ServerEndpoint]()
    
    // No authentication required because this doesn't do any processing within the server-- just a check to ensure the server is running.
    public static let healthCheck = ServerEndpoint("HealthCheck", method: .get, authenticationLevel: .none)

#if DEBUG
    public static let checkPrimaryCreds = ServerEndpoint("CheckPrimaryCreds", method: .get, authenticationLevel: .primary)
#endif

    public static let checkCreds = ServerEndpoint("CheckCreds", method: .get)
    
    // This creates a "root" owning user account for a sharing group of users. The user must not exist yet on the system.
    // Only primary authentication because this method is used to add a user into the database (i.e., it creates secondary authentication).
    public static let addUser = ServerEndpoint("AddUser", method: .post, authenticationLevel: .primary)

    // Removes the calling user from the system.
    public static let removeUser = ServerEndpoint("RemoveUser", method: .post)
    
    // The FileIndex serves as a kind of snapshot of the files on the server for the calling apps. So, we hold the lock while we take the snapshot-- to make sure we're not getting a cross section of changes imposed by other apps.
    public static let fileIndex = ServerEndpoint("FileIndex", method: .get, needsLock:true)
    
    public static let uploadFile = ServerEndpoint("UploadFile", method: .post, minPermission: .write)
    
    // Useful if only the app meta data has changed, so you don't have to re-upload the entire file.
    public static let uploadAppMetaData = ServerEndpoint("UploadAppMetaData", method: .post, minPermission: .write)
    
    // Any time we're doing an operation constrained to the current masterVersion, holding the lock seems like a good idea.
    public static let uploadDeletion = ServerEndpoint("UploadDeletion", method: .delete, needsLock:true, minPermission: .write)

    // TODO: *0* See also [1] in FileControllerTests.swift.
    // Seems unlikely that the collection of uploads will change while we are getting them (because they are specific to the userId and the deviceUUID), but grab the lock just in case.
    public static let getUploads = ServerEndpoint("GetUploads", method: .get, needsLock:true, minPermission: .write)
    
    // Not using `needsLock` property here-- but doing the locking internally to the method: Because we have to access cloud storage to deal with upload deletions.
    public static let doneUploads = ServerEndpoint("DoneUploads", method: .post, minPermission: .write)

    public static let downloadFile = ServerEndpoint("DownloadFile", method: .get)
    
    // Useful if only the app meta data has changed, so you don't have to re-download the entire file.
    public static let downloadAppMetaData = ServerEndpoint("DownloadAppMetaData", method: .get)
    
    // MARK: Sharing
    
    public static let createSharingInvitation = ServerEndpoint("CreateSharingInvitation", method: .post, minPermission: .admin)
    
    // This creates a sharing user account. The user must not exist yet on the system.
    // Only primary authentication because this method is used to add a user into the database (i.e., it creates secondary authentication).
    public static let redeemSharingInvitation = ServerEndpoint("RedeemSharingInvitation", method: .post, authenticationLevel: .primary)

    public static let getSharingGroups = ServerEndpoint("GetSharingGroups", method: .get, authenticationLevel: .secondary)

    public static let session = ServerEndpoints()
    
    private init() {
        all.append(contentsOf: [ServerEndpoints.healthCheck, ServerEndpoints.addUser, ServerEndpoints.checkCreds, ServerEndpoints.removeUser, ServerEndpoints.fileIndex, ServerEndpoints.uploadFile, ServerEndpoints.doneUploads, ServerEndpoints.getUploads, ServerEndpoints.uploadDeletion,
            ServerEndpoints.createSharingInvitation, ServerEndpoints.redeemSharingInvitation, ServerEndpoints.getSharingGroups])
    }
}
