//
//  SyncServerError.swift
//  SyncServer
//
//  Created by Christopher G Prince on 1/3/18.
//

import Foundation

/// Many of these only have internal meaning to the client interface. Some are documented because they can be useful to the code using the client.
public enum SyncServerError: Error {
    /// If this is reported, it is diagnostic of a network error. It is not reported simply due to a check for a cellular data connection. i.e., no network was present and this may be the reason why.
    case noCellularDataConnection

    /// The network connection was lost.
    case noNetworkError
    
    /// The minimum server version you gave in `appLaunchSetup` was not met. Immediately this is raised as an error, the SyncServer client stops operating.
    case badServerVersion(actualServerVersion: ServerVersion?)
    
    case mimeTypeOfFileChanged
    case noMimeType
    case badMimeType
    case downloadedFileVersionNotGreaterThanCurrent
    case fileAlreadyDeleted
    case fileGroupUUIDChanged
    case fileQueuedForDeletion
    case deletingUnknownFile
    case getAttributesForUnknownFile
    case syncIsOperating
    case alreadyDownloadingAFile
    case alreadyUploadingAFile
    case couldNotFindFileUUID(String)
    case versionForFileWasNil(fileUUUID: String)
    case noRefreshAvailable
    case couldNotCreateResponse
    case couldNotCreateRequest
    case didNotGetDownloadURL
    case couldNotMoveDownloadFile
    case couldNotCreateNewFile
    case couldNotRemoveFileTracker
    case badAppMetaData
    case noExpectedResultKey
    case nilResponse
    case couldNotObtainHeaderParameters
    case resultURLObtainedWasNil
    case errorConvertingServerResponse
    case jsonSerializationError(Error)
    case urlSessionError(Error)
    case couldNotGetHTTPURLResponse
    case non200StatusCode(Int)
    case badCheckCreds
    case badAddUser
    case appMetaDataUploadUndeletionAttempt
    case sharingGroupUUIDInconsistent
    case noSharingGroupUUID
    case unknownServerError
    case coreDataError(Error)
    case otherError(Error)
    case fileManagerError(Error)
    case generic(String)
    case couldNotComputeHash
    
    // The checksum in cloud storage didn't match what we computed locally after the download.
    case networkingHashMismatch
    
#if TEST_REFRESH_FAILURE
    case testRefreshFailure
#endif

    case credentialsRefreshError
    
    case socialAcceptanceNotAllowed
}
