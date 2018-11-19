//
//  ServerAPI.swift
//  Pods
//
//  Created by Christopher Prince on 12/24/16.
//
//

import Foundation
import SMCoreLib
import SyncServer_Shared

protocol ServerAPIDelegate : class {
    func deviceUUID(forServerAPI: ServerAPI) -> Foundation.UUID
    
    // Got a 401 status code back from server for current signed-in user
    func userWasUnauthorized(forServerAPI: ServerAPI)
    
#if DEBUG
    func doneUploadsRequestTestLockSync(forServerAPI: ServerAPI) -> TimeInterval?
    func indexRequestServerSleep(forServerAPI: ServerAPI) -> TimeInterval?
#endif
}

class ServerAPI {
    enum Result<T> {
        case success(T)
        case error(Error)
    }
    
    // These need to be set by user of this class.
    var baseURL:String!
    weak var delegate:ServerAPIDelegate!
    
    // Used in ServerAPI extension(s).
    weak var syncServerDelegate:SyncServerDelegate?
    
    var desiredEvents:EventDesired = .defaults

#if DEBUG
    private var _failNextEndpoint = false
    
    // Failure testing.
    var failNextEndpoint: Bool {
        // Returns the current value, and resets to false.
        get {
            let curr = _failNextEndpoint
            _failNextEndpoint = false
            return curr || failEndpoints
        }
        
        set {
            _failNextEndpoint = true
        }
    }
    
    // Fails endpoints if you set this to true.
    var failEndpoints = false
#endif
    
    fileprivate var authTokens:[String:String]?
    
    let httpUnauthorizedError = HTTPStatus.unauthorized.rawValue
    
    // If this is nil, you must use the ServerNetworking authenticationDelegate to provide credentials. Direct use of authenticationDelegate is for internal testing.
    public var creds:GenericCredentials? {
        didSet {
            updateCreds(creds)
        }
    }

    public static let session = ServerAPI()
    
    fileprivate init() {
        ServerNetworking.session.delegate = self
    }
    
    func updateCreds(_ creds:GenericCredentials?) {
        authTokens = creds?.httpRequestHeaders
    }
    
    func checkForError(statusCode:Int?, error:SyncServerError?) -> SyncServerError? {
        if statusCode == HTTPStatus.ok.rawValue || statusCode == nil  {
            return error
        }
        else {
            return .non200StatusCode(statusCode!)
        }
    }
    
    // MARK: Health check
    
    func makeURL(forEndpoint endpoint:ServerEndpoint, parameters:String? = nil) -> URL {
        var path = endpoint.pathWithSuffixSlash
        if parameters != nil {
            path += "?" + parameters!
        }
        
        return URL(string: baseURL + path)!
    }
    
    func healthCheck(completion:((HealthCheckResponse?, SyncServerError?)->(Void))?) {
        let endpoint = ServerEndpoints.healthCheck
        let url = makeURL(forEndpoint: endpoint)
        
        sendRequestUsing(method: endpoint.method, toURL: url) { (response,  httpStatus, error) in
            let resultError = self.checkForError(statusCode: httpStatus, error: error)
            
            if resultError == nil {
                if let response = response, let healthCheckResponse = HealthCheckResponse(json: response) {
                    completion?(healthCheckResponse, nil)
                }
                else {
                    completion?(nil, .couldNotCreateResponse)
                }
            }
            else {
                completion?(nil, resultError)
            }
        }
    }

    // MARK: Authentication/user-sign in
    
    // Adds the user specified by the creds property (or authenticationDelegate in ServerNetworking if that is nil).
    // If the type of owning user being added needs a cloud folder name, you must give it here (e.g., Google).
    public func addUser(cloudFolderName: String? = nil, sharingGroupUUID: String, sharingGroupName: String?, completion:((UserId?, SyncServerError?)->(Void))?) {
        let endpoint = ServerEndpoints.addUser
        var parameters:String?
        
        if let cloudFolderName = cloudFolderName {
            let params:[String : Any] = [
                AddUserRequest.sharingGroupNameKey: sharingGroupName as Any,
                AddUserRequest.cloudFolderNameKey: cloudFolderName,
                ServerEndpoint.sharingGroupUUIDKey: sharingGroupUUID
            ]
            
            guard let addUserRequest = AddUserRequest(json: params) else {
                completion?(nil, .couldNotCreateRequest)
                return
            }
            
            parameters = addUserRequest.urlParameters()!
        }

        let url = makeURL(forEndpoint: endpoint, parameters: parameters)

        sendRequestUsing(method: endpoint.method,
            toURL: url) { (response,  httpStatus, error) in
           
            guard let response = response else {
                completion?(nil, .nilResponse)
                return
            }
            
            let error = self.checkForError(statusCode: httpStatus, error: error)

            guard error == nil else {
                completion?(nil, error)
                return
            }
            
            guard let checkCredsResponse = AddUserResponse(json: response) else {
                completion?(nil, .badAddUser)
                return
            }
            
            completion?(checkCredsResponse.userId, nil)
        }
    }
    
    enum CheckCredsResult {
        case noUser
        case user(UserId, accessToken:String?)
    }
    
    // Checks the creds of the user specified by the creds property (or authenticationDelegate in ServerNetworking if that is nil). Because this method uses an unauthorized (401) http status code to indicate that the user doesn't exist, it will not do retries in the case of an error.
    // One of checkCredsResult or error will be non-nil.
    public func checkCreds(completion:((_ checkCredsResult:CheckCredsResult?, SyncServerError?)->(Void))?) {
        let endpoint = ServerEndpoints.checkCreds
        let url = makeURL(forEndpoint: endpoint)
        
        sendRequestUsing(method: endpoint.method, toURL: url, retryIfError: false) { (response, httpStatus, error) in

            var result:CheckCredsResult?

            if httpStatus == HTTPStatus.unauthorized.rawValue {
                result = .noUser
            }
            else if httpStatus == HTTPStatus.ok.rawValue {
                guard let checkCredsResponse = CheckCredsResponse(json: response!) else {
                    completion?(nil, .badCheckCreds)
                    return
                }
                
                let accessToken = response?[ServerConstants.httpResponseOAuth2AccessTokenKey] as? String
                result = .user(checkCredsResponse.userId, accessToken: accessToken)
            }
            
            if result == nil {
                if let errorResult = self.checkForError(statusCode: httpStatus, error: error) {
                    completion?(nil, errorResult)
                }
                else {
                    completion?(nil, .unknownServerError)
                }
            }
            else {
                completion?(result, nil)
            }
        }
    }
    
    func removeUser(retryIfError:Bool=true, completion:((SyncServerError?)->(Void))?) {
        let endpoint = ServerEndpoints.removeUser
        let url = makeURL(forEndpoint: endpoint)
        
        sendRequestUsing(method: endpoint.method, toURL: url, retryIfError: retryIfError) {
            (response,  httpStatus, error) in
            completion?(self.checkForError(statusCode: httpStatus, error: error))
        }
    }
    
    // MARK: Files
    
    struct IndexResult {
        let fileIndex: [FileInfo]?
        let masterVersion: MasterVersionInt?
        let sharingGroups:[SyncServer_Shared.SharingGroup]
    }
    
    func index(sharingGroupUUID: String?, completion:((Result<IndexResult>)->())?) {
        let endpoint = ServerEndpoints.index
        var params = [String : Any]()
        
        params[ServerEndpoint.sharingGroupUUIDKey] = sharingGroupUUID
        
#if DEBUG
        if let serverSleep = delegate?.indexRequestServerSleep(forServerAPI: self) {
            params[IndexRequest.testServerSleepKey] = Int32(serverSleep)
        }
#endif
        
        guard let indexRequest = IndexRequest(json: params) else {
            completion?(.error(SyncServerError.couldNotCreateRequest))
            return
        }

        let urlParameters = indexRequest.urlParameters()
        let url = makeURL(forEndpoint: endpoint, parameters: urlParameters)
        
        sendRequestUsing(method: endpoint.method, toURL: url) { (response,  httpStatus, error) in
            let resultError = self.checkForError(statusCode: httpStatus, error: error)
            
            if resultError == nil {
                if let indexResponse = IndexResponse(json: response!) {
                    let result = IndexResult(fileIndex: indexResponse.fileIndex, masterVersion: indexResponse.masterVersion, sharingGroups: indexResponse.sharingGroups)
                    completion?(.success(result))
                }
                else {
                    completion?(.error(SyncServerError.couldNotCreateResponse))
                }
            }
            else {
                completion?(.error(resultError!))
            }
        }
    }
    
    struct File : Filenaming {
        let localURL:URL!
        let fileUUID:String!
        let fileGroupUUID:String?
        let sharingGroupUUID: String!
        let mimeType:MimeType!
        let deviceUUID:String!
        let appMetaData:AppMetaData?
        let fileVersion:FileVersionInt!
        let checkSum:String
    }
    
    enum UploadFileResult {
        case success(creationDate: Date, updateDate: Date)
        case serverMasterVersionUpdate(Int64)
        
        // The GoneReason should never be userRemoved-- because when a user is removed, their files are marked as deleted in the FileIndex, and thus the files are generally not uploadable. It should also never be fileRemovedOrRenamed-- because a new upload would upload the next version, not accessing the current version.
        case gone(GoneReason)
    }
    
    // Set undelete = true in order to do an upload undeletion. The server file must already have been deleted. The meaning is to upload a new file version for a file that has already been deleted on the server. The use case is for conflict resolution-- when a download deletion and a file upload are taking place at the same time, and the client want's its upload to take priority over the download deletion.
    func uploadFile(file:File, serverMasterVersion:MasterVersionInt, undelete:Bool = false, completion:((UploadFileResult?, SyncServerError?)->(Void))?) {
        let endpoint = ServerEndpoints.uploadFile

        Log.special("file.fileUUID: \(String(describing: file.fileUUID))")

        var params:[String : Any] = [
            UploadFileRequest.fileUUIDKey: file.fileUUID,
            UploadFileRequest.mimeTypeKey: file.mimeType.rawValue,
            UploadFileRequest.fileVersionKey: file.fileVersion,
            UploadFileRequest.masterVersionKey: serverMasterVersion,
            ServerEndpoint.sharingGroupUUIDKey: file.sharingGroupUUID,
            UploadFileRequest.checkSumKey: file.checkSum
        ]
        
        if file.fileVersion == 0 {
            params[UploadFileRequest.fileGroupUUIDKey] = file.fileGroupUUID
        }
        
        if undelete {
            params[UploadFileRequest.undeleteServerFileKey] = 1
        }
        
        guard let uploadRequest = UploadFileRequest(json: params) else {
            completion?(nil, .couldNotCreateRequest)
            return
        }
        
        uploadRequest.appMetaData = file.appMetaData
        
        assert(endpoint.method == .post)
        
        let parameters = uploadRequest.urlParameters()!
        let url = makeURL(forEndpoint: endpoint, parameters: parameters)
        let networkingFile = ServerNetworkingLoadingFile(fileUUID: file.fileUUID, fileVersion: file.fileVersion)

        upload(file: networkingFile, fromLocalURL: file.localURL, toServerURL: url, method: endpoint.method) { (response, uploadResponseBody, httpStatus, error) in

            if httpStatus == HTTPStatus.gone.rawValue,
                let goneReasonRaw = uploadResponseBody?[GoneReason.goneReasonKey] as? String,
                let goneReason = GoneReason(rawValue: goneReasonRaw) {
                completion?(UploadFileResult.gone(goneReason), nil)
                return
            }
            
            let resultError = self.checkForError(statusCode: httpStatus, error: error)

            if resultError == nil {
                Log.msg("response!.allHeaderFields: \(response!.allHeaderFields)")
                if let parms = response!.allHeaderFields[ServerConstants.httpResponseMessageParams] as? String,
                    let jsonDict = self.toJSONDictionary(jsonString: parms) {
                    Log.msg("jsonDict: \(jsonDict)")
                    
                    guard let uploadFileResponse = UploadFileResponse(json: jsonDict) else {
                        completion?(nil, .couldNotCreateResponse)
                        return
                    }
                    
                    if let versionUpdate = uploadFileResponse.masterVersionUpdate {
                        let message = UploadFileResult.serverMasterVersionUpdate(versionUpdate)
                        Log.msg("\(message)")
                        completion?(message, nil)
                        return
                    }
                    
                    guard let creationDate = uploadFileResponse.creationDate, let updateDate = uploadFileResponse.updateDate else {
                        completion?(nil, .noExpectedResultKey)
                        return
                    }
                    
                    completion?(UploadFileResult.success(creationDate: creationDate, updateDate: updateDate), nil)
                }
                else {
                    completion?(nil, .couldNotObtainHeaderParameters)
                }
            }
            else {
                completion?(nil, resultError)
            }
        }
    }
    
    enum DoneUploadsResult {
        case success(numberUploadsTransferred:Int64)
        case serverMasterVersionUpdate(Int64)
    }
    
    // I'm providing a numberOfDeletions parameter here because the duration of these requests varies, if we're doing deletions, based on the number of items we're deleting.
    func doneUploads(serverMasterVersion:MasterVersionInt!, sharingGroupUUID: String, numberOfDeletions:UInt = 0, sharingGroupNameUpdate: String? = nil, completion:((DoneUploadsResult?, SyncServerError?)->(Void))?) {
        let endpoint = ServerEndpoints.doneUploads
        
        // See https://developer.apple.com/reference/foundation/nsurlsessionconfiguration/1408259-timeoutintervalforrequest
        
        var timeoutIntervalForRequest:TimeInterval = ServerNetworking.defaultTimeout
        if numberOfDeletions > 0 {
            timeoutIntervalForRequest += Double(numberOfDeletions) * 5.0
        }
        
        var params = [String : Any]()
        params[ServerEndpoint.masterVersionKey] = serverMasterVersion
        params[ServerEndpoint.sharingGroupUUIDKey] = sharingGroupUUID
        
        if let sharingGroupNameUpdate = sharingGroupNameUpdate {
            params[DoneUploadsRequest.sharingGroupNameKey] = sharingGroupNameUpdate
        }
        
#if DEBUG
        if let testLockSync = delegate?.doneUploadsRequestTestLockSync(forServerAPI: self) {
            params[DoneUploadsRequest.testLockSyncKey] = Int32(testLockSync)
        }
#endif
        
        guard let doneUploadsRequest = DoneUploadsRequest(json: params) else {
            completion?(nil, .couldNotCreateRequest)
            return
        }

        let parameters = doneUploadsRequest.urlParameters()!
        let url = makeURL(forEndpoint: endpoint, parameters: parameters)

        sendRequestUsing(method: endpoint.method, toURL: url, timeoutIntervalForRequest:timeoutIntervalForRequest) { (response,  httpStatus, error) in
        
            let resultError = self.checkForError(statusCode: httpStatus, error: error)

            if resultError == nil {
                if let numberUploads = response?[DoneUploadsResponse.numberUploadsTransferredKey] as? Int64 {
                    completion?(DoneUploadsResult.success(numberUploadsTransferred:numberUploads), nil)
                }
                else if let masterVersionUpdate = response?[ServerEndpoint.masterVersionUpdateKey] as? Int64 {
                    completion?(DoneUploadsResult.serverMasterVersionUpdate(masterVersionUpdate), nil)
                } else {
                    completion?(nil, .noExpectedResultKey)
                }
            }
            else {
                completion?(nil, resultError)
            }
        }
    }
    
    struct DownloadedFile {
        let url: SMRelativeLocalURL
        let appMetaData:AppMetaData?
        let checkSum:String // in cloud storage
        let cloudStorageType:CloudStorageType
        let contentsChangedOnServer: Bool
    }
    
    enum DownloadFileResult {
        case success(DownloadedFile)
        case serverMasterVersionUpdate(Int64)
        
        // the GoneReason should never be userRemoved-- because when a user is removed, their files are marked as deleted in the FileIndex, and thus the files are generally not downloadable.
        case gone(GoneReason)
    }
    
    func downloadFile(fileNamingObject: FilenamingWithAppMetaDataVersion, serverMasterVersion:MasterVersionInt!, sharingGroupUUID: String, completion:((DownloadFileResult?, SyncServerError?)->(Void))?) {
        let endpoint = ServerEndpoints.downloadFile
        
        var params = [String : Any]()
        params[DownloadFileRequest.masterVersionKey] = serverMasterVersion
        params[DownloadFileRequest.fileUUIDKey] = fileNamingObject.fileUUID
        params[DownloadFileRequest.fileVersionKey] = fileNamingObject.fileVersion
        params[DownloadFileRequest.appMetaDataVersionKey] = fileNamingObject.appMetaDataVersion
        params[ServerEndpoint.sharingGroupUUIDKey] = sharingGroupUUID
        
        guard let downloadFileRequest = DownloadFileRequest(json: params) else {
            completion?(nil, .couldNotCreateRequest)
            return
        }

        let parameters = downloadFileRequest.urlParameters()!
        let serverURL = makeURL(forEndpoint: endpoint, parameters: parameters)
        let file = ServerNetworkingLoadingFile(fileUUID: fileNamingObject.fileUUID, fileVersion: fileNamingObject.fileVersion)
        
        download(file: file, fromServerURL: serverURL, method: endpoint.method) { (resultURL, response, statusCode, error) in
            
            if statusCode == HTTPStatus.gone.rawValue, let resultURL = resultURL {
                // Due to the way the download proceeds, the body of the HTTP response, with the details of the `gone` issue, are in the file referenced by the resultURL.
                
                var json:Any?
                do {
                    let data = try Data(contentsOf: resultURL as URL)
                    try json = JSONSerialization.jsonObject(with: data, options: JSONSerialization.ReadingOptions(rawValue: UInt(0)))
                } catch (let error) {
                    Log.error("Error in JSON conversion: \(error)")
                    completion?(nil, .generic("Could not get Gone details."))
                    return
                }
                
                guard let jsonDict = json as? [String: Any],
                    let goneReasonRaw = jsonDict[GoneReason.goneReasonKey] as? String,
                    let goneReason = GoneReason(rawValue: goneReasonRaw) else {
                    completion?(nil, .generic("Could not convert Gone reason."))
                    return
                }
                
                completion?(.gone(goneReason), nil)
                return
            }
            
            guard response != nil else {
                let resultError = error ?? .nilResponse
                completion?(nil, resultError)
                return
            }
            
            let resultError = self.checkForError(statusCode: statusCode, error: error)

            if resultError == nil {
                Log.msg("response!.allHeaderFields: \(response!.allHeaderFields)")
                if let parms = response!.allHeaderFields[ServerConstants.httpResponseMessageParams] as? String,
                    let jsonDict = self.toJSONDictionary(jsonString: parms) {
                    Log.msg("jsonDict: \(jsonDict)")
                    
                    guard let downloadFileResponse = DownloadFileResponse(json: jsonDict) else {
                        completion?(nil, .couldNotObtainHeaderParameters)
                        return
                    }

                    if let checkSum = downloadFileResponse.checkSum,
                        let cloudStorageTypeRaw = downloadFileResponse.cloudStorageType,
                        let cloudStorageType = CloudStorageType(rawValue: cloudStorageTypeRaw),
                        let contentsChanged = downloadFileResponse.contentsChanged {

                        guard resultURL != nil else {
                            completion?(nil, .resultURLObtainedWasNil)
                            return
                        }
                        
                        guard let hash = Hashing.hashOf(url: resultURL! as URL, for: cloudStorageType) else {
                            completion?(nil, .couldNotComputeHash)
                            return
                        }
                        
                        guard hash == checkSum else {
                            // Considering this to be a networking error and not something we want to pass up to the client app. This shouldn't happen in normal operation.
                            completion?(nil, .networkingHashMismatch)
                            return
                        }

                        let appMetaData = AppMetaData(version: fileNamingObject.appMetaDataVersion, contents: downloadFileResponse.appMetaData)
                        
                        let downloadedFile = DownloadedFile(url: resultURL!, appMetaData: appMetaData, checkSum: checkSum, cloudStorageType: cloudStorageType, contentsChangedOnServer: contentsChanged)
                        completion?(.success(downloadedFile), nil)
                    }
                    else if let masterVersionUpdate = jsonDict[DownloadFileResponse.masterVersionUpdateKey] as? Int64 {
                        completion?(DownloadFileResult.serverMasterVersionUpdate(masterVersionUpdate), nil)
                    } else {
                        completion?(nil, .noExpectedResultKey)
                    }
                }
                else {
                    completion?(nil, .couldNotObtainHeaderParameters)
                }
            }
            else {
                completion?(nil, resultError)
            }
        }
    }
    
    private func toJSONDictionary(jsonString:String) -> [String:Any]? {
        guard let data = jsonString.data(using: String.Encoding.utf8) else {
            return nil
        }
        
        var json:Any?
        
        do {
            try json = JSONSerialization.jsonObject(with: data, options: JSONSerialization.ReadingOptions(rawValue: UInt(0)))
        } catch (let error) {
            Log.error("toJSONDictionary: Error in JSON conversion: \(error)")
            return nil
        }
        
        guard let jsonDict = json as? [String:Any] else {
            Log.error("Could not convert json to json Dict")
            return nil
        }
        
        return jsonDict
    }
        
    func getUploads(sharingGroupUUID: String, completion:((_ fileIndex: [FileInfo]?, SyncServerError?)->(Void))?) {
    
        let endpoint = ServerEndpoints.getUploads
        var params = [String : Any]()
        params[ServerEndpoint.sharingGroupUUIDKey] = sharingGroupUUID
        
        guard let getUploadsRequest = GetUploadsRequest(json: params) else {
            completion?(nil, .couldNotCreateRequest)
            return
        }

        let parameters = getUploadsRequest.urlParameters()!
        let serverURL = makeURL(forEndpoint: endpoint, parameters: parameters)
        
        sendRequestUsing(method: endpoint.method, toURL: serverURL) { (response,  httpStatus, error) in
            let resultError = self.checkForError(statusCode: httpStatus, error: error)
            
            if resultError == nil {
                if let getUploadsResponse = GetUploadsResponse(json: response!) {
                    completion?(getUploadsResponse.uploads, nil)
                }
                else {
                    completion?(nil, .couldNotCreateResponse)
                }
            }
            else {
                completion?(nil, resultError)
            }
        }
    }
    
    enum UploadDeletionResult {
        case success
        case serverMasterVersionUpdate(Int64)
    }
    
    struct FileToDelete {
        let fileUUID:String!
        let fileVersion:FileVersionInt!
        let sharingGroupUUID: String!
        
#if DEBUG
        var actualDeletion:Bool = false
#endif

        init(fileUUID:String, fileVersion:FileVersionInt, sharingGroupUUID: String) {
            self.fileUUID = fileUUID
            self.fileVersion = fileVersion
            self.sharingGroupUUID = sharingGroupUUID
        }
    }
    
    enum UploadDeletionError : Error {
        case getUploadDeletionResponseConversionError
    }
    
    // TODO: *3* It would be *much* faster, at least in some testing situations, to batch together a group of deletions for upload-- instead of uploading them one by one.
    func uploadDeletion(file: FileToDelete, serverMasterVersion:MasterVersionInt!, completion:((UploadDeletionResult?, SyncServerError?)->(Void))?) {
        let endpoint = ServerEndpoints.uploadDeletion
                
        var paramsForRequest:[String:Any] = [:]
        paramsForRequest[UploadDeletionRequest.fileUUIDKey] = file.fileUUID
        paramsForRequest[UploadDeletionRequest.fileVersionKey] = file.fileVersion
        paramsForRequest[UploadDeletionRequest.masterVersionKey] = serverMasterVersion
        paramsForRequest[ServerEndpoint.sharingGroupUUIDKey] = file.sharingGroupUUID

#if DEBUG
        if file.actualDeletion {
            paramsForRequest[UploadDeletionRequest.actualDeletionKey] = 1
        }
#endif
        
        let uploadDeletion = UploadDeletionRequest(json: paramsForRequest)!
        
        let parameters = uploadDeletion.urlParameters()!
        let serverURL = makeURL(forEndpoint: endpoint, parameters: parameters)
        
        sendRequestUsing(method: endpoint.method, toURL: serverURL) { (response,  httpStatus, error) in
            let resultError = self.checkForError(statusCode: httpStatus, error: error)
            
            if resultError == nil {
                if let uploadDeletionResponse = UploadDeletionResponse(json: response!) {
                    if let masterVersionUpdate = uploadDeletionResponse.masterVersionUpdate {
                        completion?(UploadDeletionResult.serverMasterVersionUpdate(masterVersionUpdate), nil)
                    }
                    else {
                        completion?(UploadDeletionResult.success, nil)
                    }
                }
                else {
                    completion?(nil, .couldNotCreateResponse)
                }
            }
            else {
                completion?(nil, resultError)
            }
        }
    }
    
    enum CreateSharingInvitationError: Error {
        case responseConversionError
    }

    func createSharingInvitation(withPermission permission:Permission, sharingGroupUUID: String, completion:((_ sharingInvitationUUID:String?, Error?)->(Void))?) {
    
        let endpoint = ServerEndpoints.createSharingInvitation

        var paramsForRequest:[String:Any] = [:]
        paramsForRequest[CreateSharingInvitationRequest.permissionKey] = permission
        paramsForRequest[ServerEndpoint.sharingGroupUUIDKey] = sharingGroupUUID
        let invitationRequest = CreateSharingInvitationRequest(json: paramsForRequest)!
        
        let parameters = invitationRequest.urlParameters()!
        let serverURL = makeURL(forEndpoint: endpoint, parameters: parameters)
        
        sendRequestUsing(method: endpoint.method, toURL: serverURL) { (response,  httpStatus, error) in
            let resultError = self.checkForError(statusCode: httpStatus, error: error)
            
            if resultError == nil {
                if let invitationResponse = CreateSharingInvitationResponse(json: response!) {
                    completion?(invitationResponse.sharingInvitationUUID, nil)
                }
                else {
                    completion?(nil, CreateSharingInvitationError.responseConversionError)
                }
            }
            else {
                completion?(nil, resultError)
            }
        }
    }

    enum RedeemSharingInvitationError: Error {
        case responseConversionError
    }
    
    // Some accounts return an access token after sign-in (e.g., Facebook's long-lived access token).
    // When redeeming a sharing invitation for an owning user account type that requires a cloud folder, you must give a cloud folder in the redeeming request.
    func redeemSharingInvitation(sharingInvitationUUID:String, cloudFolderName: String?, completion:((_ accessToken:String?, _ sharingGroupUUID: String?, SyncServerError?)->(Void))?) {
        let endpoint = ServerEndpoints.redeemSharingInvitation

        var paramsForRequest:[String:Any] = [:]
        paramsForRequest[RedeemSharingInvitationRequest.sharingInvitationUUIDKey] = sharingInvitationUUID
        if let cloudFolderName = cloudFolderName {
            paramsForRequest[AddUserRequest.cloudFolderNameKey] = cloudFolderName
        }
        let redeemRequest = RedeemSharingInvitationRequest(json: paramsForRequest)!
        
        let parameters = redeemRequest.urlParameters()!
        let serverURL = makeURL(forEndpoint: endpoint, parameters: parameters)
        
        sendRequestUsing(method: endpoint.method, toURL: serverURL) { (response,  httpStatus, error) in
            let resultError = self.checkForError(statusCode: httpStatus, error: error)
            
            if resultError == nil {
                if let invitationResponse = RedeemSharingInvitationResponse(json: response!) {
                    let accessToken = response?[ServerConstants.httpResponseOAuth2AccessTokenKey] as? String
                    completion?(accessToken, invitationResponse.sharingGroupUUID, nil)
                }
                else {
                    completion?(nil, nil, .couldNotCreateResponse)
                }
            }
            else {
                completion?(nil, nil, resultError)
            }
        }
    }
    
    enum UploadAppMetaDataResult {
        case success
        case serverMasterVersionUpdate(Int64)
    }
    
    // Note that you can't do an undeletion for an appMetaData upload-- because there is no content to upload. I.e., when an uploadDeletion occurs the file is deleted in cloud storage. Thus, there is no option for this method to undelete.
    func uploadAppMetaData(appMetaData: AppMetaData, fileUUID: String, serverMasterVersion: MasterVersionInt, sharingGroupUUID: String, completion:((Result<UploadAppMetaDataResult>)->(Void))?) {
        let endpoint = ServerEndpoints.uploadAppMetaData
        
        let uploadRequest = UploadAppMetaDataRequest()
        uploadRequest.appMetaData = appMetaData
        uploadRequest.fileUUID = fileUUID
        uploadRequest.masterVersion = serverMasterVersion
        uploadRequest.sharingGroupUUID = sharingGroupUUID
        
        let parameters = uploadRequest.urlParameters()!
        let serverURL = makeURL(forEndpoint: endpoint, parameters: parameters)
        
        sendRequestUsing(method: endpoint.method, toURL: serverURL) { (response,  httpStatus, error) in
            if let resultError = self.checkForError(statusCode: httpStatus, error: error) {
                completion?(.error(resultError))
            }
            else {
                if let uploadAppMetaDataResponse = UploadAppMetaDataResponse(json: response!) {
                    if let masterVersionUpdate = uploadAppMetaDataResponse.masterVersionUpdate {
                        completion?(.success(.serverMasterVersionUpdate(masterVersionUpdate)))
                    }
                    else {
                        completion?(.success(.success))
                    }
                }
                else {
                    completion?(.error(SyncServerError.couldNotCreateResponse))
                }
            }
        }
    }
    
    enum DownloadAppMetaDataResult {
        case appMetaData(String)
        case serverMasterVersionUpdate(Int64)
    }

    func downloadAppMetaData(appMetaDataVersion: AppMetaDataVersionInt, fileUUID: String, serverMasterVersion: MasterVersionInt, sharingGroupUUID: String, completion:((Result<DownloadAppMetaDataResult>)->())?) {
    
        let endpoint = ServerEndpoints.downloadAppMetaData
        
        var paramsForRequest:[String:Any] = [:]
        paramsForRequest[DownloadAppMetaDataRequest.fileUUIDKey] = fileUUID
        paramsForRequest[DownloadAppMetaDataRequest.appMetaDataVersionKey] = appMetaDataVersion
        paramsForRequest[DownloadAppMetaDataRequest.masterVersionKey] = serverMasterVersion
        paramsForRequest[ServerEndpoint.sharingGroupUUIDKey] = sharingGroupUUID
        let downloadAppMetaData = DownloadAppMetaDataRequest(json: paramsForRequest)!
        
        let parameters = downloadAppMetaData.urlParameters()!
        let serverURL = makeURL(forEndpoint: endpoint, parameters: parameters)
        
        sendRequestUsing(method: endpoint.method, toURL: serverURL) { (response,  httpStatus, error) in
            if let resultError = self.checkForError(statusCode: httpStatus, error: error) {
                completion?(.error(resultError))
            }
            else {
                if let downloadAppMetaDataResponse = DownloadAppMetaDataResponse(json: response!) {
                    if let masterVersionUpdate = downloadAppMetaDataResponse.masterVersionUpdate {
                        completion?(.success(.serverMasterVersionUpdate(masterVersionUpdate)))
                    }
                    else if let appMetaData = downloadAppMetaDataResponse.appMetaData {
                        completion?(.success(.appMetaData(appMetaData)))
                    }
                    else {
                        completion?(.error(SyncServerError.nilResponse))
                    }
                }
                else {
                    completion?(.error(SyncServerError.couldNotCreateResponse))
                }
            }
        }
    }
    
    // MARK: Sharing groups
    
    public func createSharingGroup(sharingGroupUUID: String, sharingGroupName: String?, completion:@escaping ((Error?)->())) {

        guard let request = CreateSharingGroupRequest(json: [
            CreateSharingGroupRequest.sharingGroupNameKey: sharingGroupName as Any,
            ServerEndpoint.sharingGroupUUIDKey: sharingGroupUUID
        ]) else {
            completion(SyncServerError.couldNotCreateRequest)
            return
        }
        
        let parameters = request.urlParameters()

        let endpoint = ServerEndpoints.createSharingGroup
        let serverURL = makeURL(forEndpoint: endpoint, parameters: parameters)
        
        sendRequestUsing(method: endpoint.method, toURL: serverURL, retryIfError: false) { (response, httpStatus, error) in

            if httpStatus == HTTPStatus.ok.rawValue, let response = response,
                let _ = CreateSharingGroupResponse(json: response) {
                completion(nil)
            }
            else if let errorResult = self.checkForError(statusCode: httpStatus, error: error) {
                completion(errorResult)
            }
            else {
                completion(SyncServerError.unknownServerError)
            }
        }
    }

    // If the result is non-nil, that means there was a master version update.
    public func removeSharingGroup(sharingGroupUUID: String, masterVersion: MasterVersionInt, completion:@escaping ((Result<MasterVersionInt?>)->())) {

        guard let request = RemoveSharingGroupRequest(json: [
            ServerEndpoint.masterVersionKey: masterVersion,
            ServerEndpoint.sharingGroupUUIDKey: sharingGroupUUID
        ]), let parameters = request.urlParameters() else {
            completion(.error(SyncServerError.couldNotCreateRequest))
            return
        }
        
        let endpoint = ServerEndpoints.removeSharingGroup
        let serverURL = makeURL(forEndpoint: endpoint, parameters: parameters)
        
        sendRequestUsing(method: endpoint.method, toURL: serverURL, retryIfError: false) { (response, httpStatus, error) in

            if httpStatus == HTTPStatus.ok.rawValue, let response = response,
                let removeResponse = RemoveSharingGroupResponse(json: response) {
                completion(.success(removeResponse.masterVersionUpdate))
            }
            else if let errorResult = self.checkForError(statusCode: httpStatus, error: error) {
                completion(.error(errorResult))
            }
            else {
                completion(.error(SyncServerError.unknownServerError))
            }
        }
    }
    
    public func updateSharingGroup(sharingGroupUUID: String, masterVersion: MasterVersionInt, sharingGroupName: String, completion:@escaping ((Result<MasterVersionInt?>)->())) {
        
        guard let request = UpdateSharingGroupRequest(json: [
            ServerEndpoint.masterVersionKey: masterVersion,
            ServerEndpoint.sharingGroupUUIDKey: sharingGroupUUID,
            UpdateSharingGroupRequest.sharingGroupNameKey: sharingGroupName
        ]), let parameters = request.urlParameters() else {
            completion(.error(SyncServerError.couldNotCreateRequest))
            return
        }
        
        let endpoint = ServerEndpoints.updateSharingGroup
        let serverURL = makeURL(forEndpoint: endpoint, parameters: parameters)
        
        sendRequestUsing(method: endpoint.method, toURL: serverURL, retryIfError: false) { (response, httpStatus, error) in

            if httpStatus == HTTPStatus.ok.rawValue, let response = response,
                let updateResponse = UpdateSharingGroupResponse(json: response) {
                completion(.success(updateResponse.masterVersionUpdate))
            }
            else if let errorResult = self.checkForError(statusCode: httpStatus, error: error) {
                completion(.error(errorResult))
            }
            else {
                completion(.error(SyncServerError.unknownServerError))
            }
        }
    }
    
    public func removeUserFromSharingGroup(sharingGroupUUID: String, masterVersion: MasterVersionInt, completion:@escaping ((Result<MasterVersionInt?>)->())) {
        
        guard let request = RemoveUserFromSharingGroupRequest(json: [
            ServerEndpoint.masterVersionKey: masterVersion,
            ServerEndpoint.sharingGroupUUIDKey: sharingGroupUUID
        ]), let parameters = request.urlParameters() else {
            completion(.error(SyncServerError.couldNotCreateRequest))
            return
        }
        
        let endpoint = ServerEndpoints.removeUserFromSharingGroup
        let serverURL = makeURL(forEndpoint: endpoint, parameters: parameters)
        
        sendRequestUsing(method: endpoint.method, toURL: serverURL, retryIfError: false) { (response, httpStatus, error) in

            if httpStatus == HTTPStatus.ok.rawValue, let response = response,
                let removeResponse = RemoveUserFromSharingGroupResponse(json: response) {
                completion(.success(removeResponse.masterVersionUpdate))
            }
            else if let errorResult = self.checkForError(statusCode: httpStatus, error: error) {
                completion(.error(errorResult))
            }
            else {
                completion(.error(SyncServerError.unknownServerError))
            }
        }
    }
}

extension ServerAPI : ServerNetworkingDelegate {    
    func serverNetworkingHeaderAuthentication(forServerNetworking: Any?) -> [String:String]? {
        var result = [String:String]()
        if self.authTokens != nil {
            for (key, value) in self.authTokens! {
                result[key] = value
            }
        }
        
        // August/2017-- I got a couple of crashes that seemed to have occurred right here. They occurred when the app launched. Previously, I had delegate.deviceUUID. I've now changed that to device?.deviceUUID.
        result[ServerConstants.httpRequestDeviceUUID] = delegate?.deviceUUID(forServerAPI: self).uuidString
        
#if DEBUG
        if failNextEndpoint {
            result[ServerConstants.httpRequestEndpointFailureTestKey] = "true"
        }
#endif
        
        return result
    }
}

