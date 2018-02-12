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
    func fileIndexRequestServerSleep(forServerAPI: ServerAPI) -> TimeInterval?
#endif
}

class ServerAPI {
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
    
    // Fails endpoints until you set this to true.
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
    public func addUser(completion:((UserId?, SyncServerError?)->(Void))?) {
        let endpoint = ServerEndpoints.addUser
        let url = makeURL(forEndpoint: endpoint)
        
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
    case owningUser(UserId)
    case sharingUser(UserId, sharingPermission:SharingPermission, accessToken:String?)
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
                
                if checkCredsResponse.sharingPermission == nil {
                    result = .owningUser(checkCredsResponse.userId)
                }
                else {
                    let accessToken = response?[ServerConstants.httpResponseOAuth2AccessTokenKey] as? String
                    result = .sharingUser(checkCredsResponse.userId, sharingPermission: checkCredsResponse.sharingPermission!, accessToken: accessToken)
                }
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
        
    func fileIndex(completion:((_ fileIndex: [FileInfo]?, _ masterVersion:MasterVersionInt?, SyncServerError?)->(Void))?) {
    
        let endpoint = ServerEndpoints.fileIndex
        var params = [String : Any]()
        
#if DEBUG
        if let serverSleep = delegate?.fileIndexRequestServerSleep(forServerAPI: self) {
            params[FileIndexRequest.testServerSleepKey] = Int32(serverSleep)
        }
#endif
        
        guard let fileIndexRequest = FileIndexRequest(json: params) else {
            completion?(nil, nil, .couldNotCreateRequest)
            return
        }

        let urlParameters = fileIndexRequest.urlParameters()
        let url = makeURL(forEndpoint: endpoint, parameters: urlParameters)
        
        sendRequestUsing(method: endpoint.method, toURL: url) { (response,  httpStatus, error) in
            let resultError = self.checkForError(statusCode: httpStatus, error: error)
            
            if resultError == nil {
                if let fileIndexResponse = FileIndexResponse(json: response!) {
                    completion?(fileIndexResponse.fileIndex, fileIndexResponse.masterVersion, nil)
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
    
    struct File : Filenaming {
        let localURL:URL!
        let fileUUID:String!
        let mimeType:String!
        let cloudFolderName:String!
        let deviceUUID:String!
        let appMetaData:String?
        let fileVersion:FileVersionInt!
    }
    
    enum UploadFileResult {
    case success(sizeInBytes:Int64, creationDate: Date, updateDate: Date)
    case serverMasterVersionUpdate(Int64)
    }
    
    // Set undelete = true in order to do an upload undeletion. The server file must already have been deleted. The meaning is to upload a new file version for a file that has already been deleted on the server. The use case is for conflict resolution-- when a download deletion and a file upload are taking place at the same time, and the client want's its upload to take priority over the download deletion.
    func uploadFile(file:File, serverMasterVersion:MasterVersionInt, undelete:Bool = false, completion:((UploadFileResult?, SyncServerError?)->(Void))?) {
        let endpoint = ServerEndpoints.uploadFile

        Log.special("file.fileUUID: \(file.fileUUID)")

        var params:[String : Any] = [
            UploadFileRequest.fileUUIDKey: file.fileUUID,
            UploadFileRequest.mimeTypeKey: file.mimeType,
            UploadFileRequest.cloudFolderNameKey: file.cloudFolderName,
            UploadFileRequest.appMetaDataKey: file.appMetaData as Any,
            UploadFileRequest.fileVersionKey: file.fileVersion,
            UploadFileRequest.masterVersionKey: serverMasterVersion
        ]
        
        if undelete {
            params[UploadFileRequest.undeleteServerFileKey] = 1
        }
        
        guard let uploadRequest = UploadFileRequest(json: params) else {
            completion?(nil, .couldNotCreateRequest);
            return;
        }
        
        assert(endpoint.method == .post)
        
        let parameters = uploadRequest.urlParameters()!
        let url = makeURL(forEndpoint: endpoint, parameters: parameters)
        let networkingFile = ServerNetworkingLoadingFile(fileUUID: file.fileUUID, fileVersion: file.fileVersion)

        upload(file: networkingFile, fromLocalURL: file.localURL, toServerURL: url, method: endpoint.method) { (response, httpStatus, error) in
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
                    
                    guard let size = uploadFileResponse.size, let creationDate = uploadFileResponse.creationDate, let updateDate = uploadFileResponse.updateDate else {
                        completion?(nil, .noExpectedResultKey)
                        return
                    }
                    
                    completion?(UploadFileResult.success(sizeInBytes:size, creationDate: creationDate, updateDate: updateDate), nil)
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
    func doneUploads(serverMasterVersion:MasterVersionInt!, numberOfDeletions:UInt = 0, completion:((DoneUploadsResult?, SyncServerError?)->(Void))?) {
        let endpoint = ServerEndpoints.doneUploads
        
        // See https://developer.apple.com/reference/foundation/nsurlsessionconfiguration/1408259-timeoutintervalforrequest
        let defaultTimeout = 60.0
        
        var timeoutIntervalForRequest:TimeInterval?
        if numberOfDeletions > 0 {
            timeoutIntervalForRequest = defaultTimeout + Double(numberOfDeletions) * 5.0
        }
        
        var params = [String : Any]()
        params[DoneUploadsRequest.masterVersionKey] = serverMasterVersion
        
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
                else if let masterVersionUpdate = response?[DoneUploadsResponse.masterVersionUpdateKey] as? Int64 {
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
    let fileSizeBytes:Int64
    let appMetaData:String?
    }
    
    enum DownloadFileResult {
    case success(DownloadedFile)
    case serverMasterVersionUpdate(Int64)
    }
    
    func downloadFile(file: Filenaming, serverMasterVersion:MasterVersionInt!, completion:((DownloadFileResult?, SyncServerError?)->(Void))?) {
        let endpoint = ServerEndpoints.downloadFile
        
        var params = [String : Any]()
        params[DownloadFileRequest.masterVersionKey] = serverMasterVersion
        params[DownloadFileRequest.fileUUIDKey] = file.fileUUID
        params[DownloadFileRequest.fileVersionKey] = file.fileVersion

        guard let downloadFileRequest = DownloadFileRequest(json: params) else {
            completion?(nil, .couldNotCreateRequest)
            return
        }

        let parameters = downloadFileRequest.urlParameters()!
        let serverURL = makeURL(forEndpoint: endpoint, parameters: parameters)
        let file = ServerNetworkingLoadingFile(fileUUID: file.fileUUID, fileVersion: file.fileVersion)
        
        download(file: file, fromServerURL: serverURL, method: endpoint.method) { (resultURL, response, statusCode, error) in
        
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

                    if let fileSizeBytes = jsonDict[DownloadFileResponse.fileSizeBytesKey] as? Int64 {
                        var appMetaDataString:String?
                        let appMetaData = jsonDict[DownloadFileResponse.appMetaDataKey]
                        if appMetaData != nil {
                            if appMetaData is String {
                                appMetaDataString = (appMetaData as! String)
                            }
                            else {
                                completion?(nil, .obtainedAppMetaDataButWasNotString)
                                return
                            }
                        }
                        
                        guard resultURL != nil else {
                            completion?(nil, .resultURLObtainedWasNil)
                            return
                        }
                        
                        let downloadedFile = DownloadedFile(url: resultURL!, fileSizeBytes: fileSizeBytes, appMetaData: appMetaDataString)
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
        
    func getUploads(completion:((_ fileIndex: [FileInfo]?, SyncServerError?)->(Void))?) {
    
        let endpoint = ServerEndpoints.getUploads
        
        let url = makeURL(forEndpoint: endpoint)
        
        sendRequestUsing(method: endpoint.method, toURL: url) { (response,  httpStatus, error) in
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
        
#if DEBUG
        var actualDeletion:Bool = false
#endif

        init(fileUUID:String, fileVersion:FileVersionInt) {
            self.fileUUID = fileUUID
            self.fileVersion = fileVersion
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

    func createSharingInvitation(withPermission permission:SharingPermission, completion:((_ sharingInvitationUUID:String?, Error?)->(Void))?) {
    
        let endpoint = ServerEndpoints.createSharingInvitation

        var paramsForRequest:[String:Any] = [:]
        paramsForRequest[CreateSharingInvitationRequest.sharingPermissionKey] = permission
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
    func redeemSharingInvitation(sharingInvitationUUID:String, completion:((_ accessToken:String?, SyncServerError?)->(Void))?) {
        let endpoint = ServerEndpoints.redeemSharingInvitation

        var paramsForRequest:[String:Any] = [:]
        paramsForRequest[RedeemSharingInvitationRequest.sharingInvitationUUIDKey] = sharingInvitationUUID
        let redeemRequest = RedeemSharingInvitationRequest(json: paramsForRequest)!
        
        let parameters = redeemRequest.urlParameters()!
        let serverURL = makeURL(forEndpoint: endpoint, parameters: parameters)
        
        sendRequestUsing(method: endpoint.method, toURL: serverURL) { (response,  httpStatus, error) in
            let resultError = self.checkForError(statusCode: httpStatus, error: error)
            
            if resultError == nil {
                if RedeemSharingInvitationResponse(json: response!) != nil {
                    let accessToken = response?[ServerConstants.httpResponseOAuth2AccessTokenKey] as? String
                    completion?(accessToken, nil)
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
