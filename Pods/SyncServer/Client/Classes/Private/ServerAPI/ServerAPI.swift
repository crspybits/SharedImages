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
                if let response = response,
                    let healthCheckResponse = try? HealthCheckResponse.decode(response) {
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
            let addUserRequest = AddUserRequest()
            addUserRequest.sharingGroupName = sharingGroupName
            addUserRequest.cloudFolderName = cloudFolderName
            addUserRequest.sharingGroupUUID = sharingGroupUUID
            
            guard addUserRequest.valid() else {
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
            
            guard let checkCredsResponse = try? AddUserResponse.decode(response) else {
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
                guard let checkCredsResponse = try? CheckCredsResponse.decode(response!) else {
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
        
        let indexRequest = IndexRequest()
        indexRequest.sharingGroupUUID = sharingGroupUUID
        
#if DEBUG
        if let serverSleep = delegate?.indexRequestServerSleep(forServerAPI: self) {
            indexRequest.testServerSleep = Int32(serverSleep)
        }
#endif
        
        guard indexRequest.valid() else {
            completion?(.error(SyncServerError.couldNotCreateRequest))
            return
        }

        let urlParameters = indexRequest.urlParameters()
        let url = makeURL(forEndpoint: endpoint, parameters: urlParameters)
        
        sendRequestUsing(method: endpoint.method, toURL: url) { (response,  httpStatus, error) in
            let resultError = self.checkForError(statusCode: httpStatus, error: error)
            
            if resultError == nil {
                if let indexResponse = try? IndexResponse.decode(response!) {
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
        
        // The GoneReason should never be fileRemovedOrRenamed-- because a new upload would upload the next version, not accessing the current version.
        case gone(GoneReason)
    }
    
    // Set undelete = true in order to do an upload undeletion. The server file must already have been deleted. The meaning is to upload a new file version for a file that has already been deleted on the server. The use case is for conflict resolution-- when a download deletion and a file upload are taking place at the same time, and the client want's its upload to take priority over the download deletion.
    func uploadFile(file:File, serverMasterVersion:MasterVersionInt, undelete:Bool = false, completion:((UploadFileResult?, SyncServerError?)->(Void))?) {
        let endpoint = ServerEndpoints.uploadFile

        Log.special("file.fileUUID: \(String(describing: file.fileUUID))")

        let uploadRequest = UploadFileRequest()
        uploadRequest.fileUUID = file.fileUUID
        uploadRequest.mimeType = file.mimeType.rawValue
        uploadRequest.fileVersion = file.fileVersion
        uploadRequest.masterVersion = serverMasterVersion
        uploadRequest.sharingGroupUUID = file.sharingGroupUUID
        uploadRequest.checkSum = file.checkSum
        
        if file.fileVersion == 0 {
            uploadRequest.fileGroupUUID = file.fileGroupUUID
        }
        
        if undelete {
            uploadRequest.undeleteServerFile = true
        }
        
        guard uploadRequest.valid() else {
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
                    
                    guard let uploadFileResponse = try? UploadFileResponse.decode(jsonDict) else {
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
    func doneUploads(serverMasterVersion:MasterVersionInt!, sharingGroupUUID: String, numberOfDeletions:UInt = 0, sharingGroupNameUpdate: String? = nil, pushNotificationMessage: String? = nil, completion:((DoneUploadsResult?, SyncServerError?)->(Void))?) {
        let endpoint = ServerEndpoints.doneUploads
        
        // See https://developer.apple.com/reference/foundation/nsurlsessionconfiguration/1408259-timeoutintervalforrequest
        
        var timeoutIntervalForRequest:TimeInterval = ServerNetworking.defaultTimeout
        if numberOfDeletions > 0 {
            timeoutIntervalForRequest += Double(numberOfDeletions) * 5.0
        }
        
        let doneUploadsRequest = DoneUploadsRequest()
        doneUploadsRequest.masterVersion = serverMasterVersion
        doneUploadsRequest.sharingGroupUUID = sharingGroupUUID
        
        if let sharingGroupNameUpdate = sharingGroupNameUpdate {
            doneUploadsRequest.sharingGroupName = sharingGroupNameUpdate
        }
        
        if let pushNotificationMessage = pushNotificationMessage {
            doneUploadsRequest.pushNotificationMessage = pushNotificationMessage
        }
        
#if DEBUG
        if let testLockSync = delegate?.doneUploadsRequestTestLockSync(forServerAPI: self) {
            doneUploadsRequest.testLockSync = Int32(testLockSync)
        }
#endif
        
        guard doneUploadsRequest.valid() else {
            completion?(nil, .couldNotCreateRequest)
            return
        }

        let parameters = doneUploadsRequest.urlParameters()!
        let url = makeURL(forEndpoint: endpoint, parameters: parameters)

        sendRequestUsing(method: endpoint.method, toURL: url, timeoutIntervalForRequest:timeoutIntervalForRequest) { (response,  httpStatus, error) in
        
            let resultError = self.checkForError(statusCode: httpStatus, error: error)

            if resultError == nil {
                guard let response = response,
                    let doneUploadsResponse = try? DoneUploadsResponse.decode(response) else {
                    completion?(nil, .nilResponse)
                    return
                }

                if let numberUploads = doneUploadsResponse.numberUploadsTransferred {
                    completion?(DoneUploadsResult.success(numberUploadsTransferred:
                        Int64(numberUploads)), nil)
                }
                else if let masterVersionUpdate = doneUploadsResponse.masterVersionUpdate {
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
    
    enum DownloadedFile {
        case content(url: SMRelativeLocalURL, appMetaData:AppMetaData?, checkSum:String, cloudStorageType:CloudStorageType, contentsChangedOnServer: Bool)
        
        // The GoneReason should never be userRemoved-- because when a user is removed, their files are marked as deleted in the FileIndex, and thus the files are generally not downloadable.
        case gone(appMetaData:AppMetaData?, cloudStorageType:CloudStorageType, GoneReason)
    }
    
    enum DownloadFileResult {
        case success(DownloadedFile)
        case serverMasterVersionUpdate(Int64)
    }
    
    func downloadFile(fileNamingObject: FilenamingWithAppMetaDataVersion, serverMasterVersion:MasterVersionInt!, sharingGroupUUID: String, completion:((DownloadFileResult?, SyncServerError?)->(Void))?) {
        let endpoint = ServerEndpoints.downloadFile
        
        let downloadFileRequest = DownloadFileRequest()
        downloadFileRequest.masterVersion = serverMasterVersion
        downloadFileRequest.fileUUID = fileNamingObject.fileUUID
        downloadFileRequest.fileVersion = fileNamingObject.fileVersion
        downloadFileRequest.appMetaDataVersion = fileNamingObject.appMetaDataVersion
        downloadFileRequest.sharingGroupUUID = sharingGroupUUID
        
        guard downloadFileRequest.valid() else {
            completion?(nil, .couldNotCreateRequest)
            return
        }

        let parameters = downloadFileRequest.urlParameters()!
        let serverURL = makeURL(forEndpoint: endpoint, parameters: parameters)
        let file = ServerNetworkingLoadingFile(fileUUID: fileNamingObject.fileUUID, fileVersion: fileNamingObject.fileVersion)
        
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
                    
                    guard let downloadFileResponse = try? DownloadFileResponse.decode(jsonDict) else {
                        completion?(nil, .couldNotObtainHeaderParameters)
                        return
                    }
                    
                    if let masterVersionUpdate = downloadFileResponse.masterVersionUpdate {
                        completion?(DownloadFileResult.serverMasterVersionUpdate(masterVersionUpdate), nil)
                        return
                    }
                    
                    guard let cloudStorageTypeRaw = downloadFileResponse.cloudStorageType,
                        let cloudStorageType = CloudStorageType(rawValue: cloudStorageTypeRaw) else {
                        completion?(nil, .generic("Could not get CloudStorageType"))
                        return
                    }
                    
                    var appMetaData:AppMetaData?
                    
                    if fileNamingObject.appMetaDataVersion != nil && downloadFileResponse.appMetaData != nil  {
                        appMetaData = AppMetaData(version: fileNamingObject.appMetaDataVersion!, contents: downloadFileResponse.appMetaData!)
                    }

                    if let goneRaw = downloadFileResponse.gone,
                        let gone = GoneReason(rawValue: goneRaw) {
                        
                        let downloadedFile = DownloadedFile.gone(appMetaData: appMetaData, cloudStorageType: cloudStorageType, gone)
                        completion?(.success(downloadedFile), nil)
                    }
                    else if let checkSum = downloadFileResponse.checkSum,
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

                        let downloadedFile = DownloadedFile.content(url: resultURL!, appMetaData: appMetaData, checkSum: checkSum, cloudStorageType: cloudStorageType, contentsChangedOnServer: contentsChanged)
                        completion?(.success(downloadedFile), nil)
                    }
                    else {
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
        let getUploadsRequest = GetUploadsRequest()
        getUploadsRequest.sharingGroupUUID = sharingGroupUUID
        
        guard getUploadsRequest.valid() else {
            completion?(nil, .couldNotCreateRequest)
            return
        }

        let parameters = getUploadsRequest.urlParameters()!
        let serverURL = makeURL(forEndpoint: endpoint, parameters: parameters)
        
        sendRequestUsing(method: endpoint.method, toURL: serverURL) { (response,  httpStatus, error) in
            let resultError = self.checkForError(statusCode: httpStatus, error: error)
            
            if resultError == nil {
                if let getUploadsResponse = try? GetUploadsResponse.decode(response!) {
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
                
        let uploadDeletion = UploadDeletionRequest()
        uploadDeletion.fileUUID = file.fileUUID
        uploadDeletion.fileVersion = file.fileVersion
        uploadDeletion.masterVersion = serverMasterVersion
        uploadDeletion.sharingGroupUUID = file.sharingGroupUUID

#if DEBUG
        if file.actualDeletion {
            uploadDeletion.actualDeletion = true
        }
#endif
        
        let parameters = uploadDeletion.urlParameters()!
        let serverURL = makeURL(forEndpoint: endpoint, parameters: parameters)
        
        sendRequestUsing(method: endpoint.method, toURL: serverURL) { (response,  httpStatus, error) in
            let resultError = self.checkForError(statusCode: httpStatus, error: error)
            
            if resultError == nil {
                if let uploadDeletionResponse = try? UploadDeletionResponse.decode(response!) {
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

    func createSharingInvitation(withPermission permission:Permission, sharingGroupUUID: String, numberAcceptors: UInt, allowSharingAcceptance: Bool, completion:((_ sharingInvitationUUID:String?, Error?)->(Void))?) {
    
        let endpoint = ServerEndpoints.createSharingInvitation

        let invitationRequest = CreateSharingInvitationRequest()
        invitationRequest.permission = permission
        invitationRequest.sharingGroupUUID = sharingGroupUUID
        invitationRequest.allowSocialAcceptance = allowSharingAcceptance
        invitationRequest.numberOfAcceptors = numberAcceptors
        
        let parameters = invitationRequest.urlParameters()!
        let serverURL = makeURL(forEndpoint: endpoint, parameters: parameters)
        
        sendRequestUsing(method: endpoint.method, toURL: serverURL) { (response,  httpStatus, error) in
            let resultError = self.checkForError(statusCode: httpStatus, error: error)
            
            if resultError == nil {
                if let invitationResponse = try? CreateSharingInvitationResponse.decode(response!) {
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

        let redeemRequest = RedeemSharingInvitationRequest()
        redeemRequest.sharingInvitationUUID = sharingInvitationUUID
        if let cloudFolderName = cloudFolderName {
            redeemRequest.cloudFolderName = cloudFolderName
        }

        let parameters = redeemRequest.urlParameters()!
        let serverURL = makeURL(forEndpoint: endpoint, parameters: parameters)
        
        sendRequestUsing(method: endpoint.method, toURL: serverURL) { (response,  httpStatus, error) in
            let resultError = self.checkForError(statusCode: httpStatus, error: error)
            
            if resultError == nil {
                if let invitationResponse = try? RedeemSharingInvitationResponse.decode(response!) {
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
                if let uploadAppMetaDataResponse = try? UploadAppMetaDataResponse.decode(response!) {
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
        
        let downloadAppMetaData = DownloadAppMetaDataRequest()
        downloadAppMetaData.fileUUID = fileUUID
        downloadAppMetaData.appMetaDataVersion = appMetaDataVersion
        downloadAppMetaData.masterVersion = serverMasterVersion
        downloadAppMetaData.sharingGroupUUID = sharingGroupUUID
        
        let parameters = downloadAppMetaData.urlParameters()!
        let serverURL = makeURL(forEndpoint: endpoint, parameters: parameters)
        
        sendRequestUsing(method: endpoint.method, toURL: serverURL) { (response,  httpStatus, error) in
            if let resultError = self.checkForError(statusCode: httpStatus, error: error) {
                completion?(.error(resultError))
            }
            else {
                if let downloadAppMetaDataResponse = try?DownloadAppMetaDataResponse.decode(response!) {
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

        let request = CreateSharingGroupRequest()
        request.sharingGroupName = sharingGroupName
        request.sharingGroupUUID = sharingGroupUUID
        
        guard request.valid() else {
            completion(SyncServerError.couldNotCreateRequest)
            return
        }
        
        let parameters = request.urlParameters()

        let endpoint = ServerEndpoints.createSharingGroup
        let serverURL = makeURL(forEndpoint: endpoint, parameters: parameters)
        
        sendRequestUsing(method: endpoint.method, toURL: serverURL, retryIfError: false) { (response, httpStatus, error) in

            if httpStatus == HTTPStatus.ok.rawValue, let response = response,
                let _ = try? CreateSharingGroupResponse.decode(response) {
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

        let request = RemoveSharingGroupRequest()
        request.masterVersion = masterVersion
        request.sharingGroupUUID = sharingGroupUUID
        
        guard request.valid(), let parameters = request.urlParameters() else {
            completion(.error(SyncServerError.couldNotCreateRequest))
            return
        }
        
        let endpoint = ServerEndpoints.removeSharingGroup
        let serverURL = makeURL(forEndpoint: endpoint, parameters: parameters)
        
        sendRequestUsing(method: endpoint.method, toURL: serverURL, retryIfError: false) { (response, httpStatus, error) in

            if httpStatus == HTTPStatus.ok.rawValue, let response = response,
                let removeResponse = try? RemoveSharingGroupResponse.decode(response) {
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
        
        let request = UpdateSharingGroupRequest()
        request.masterVersion = masterVersion
        request.sharingGroupUUID = sharingGroupUUID
        request.sharingGroupName = sharingGroupName
        
        guard request.valid(), let parameters = request.urlParameters() else {
            completion(.error(SyncServerError.couldNotCreateRequest))
            return
        }
        
        let endpoint = ServerEndpoints.updateSharingGroup
        let serverURL = makeURL(forEndpoint: endpoint, parameters: parameters)
        
        sendRequestUsing(method: endpoint.method, toURL: serverURL, retryIfError: false) { (response, httpStatus, error) in

            if httpStatus == HTTPStatus.ok.rawValue, let response = response,
                let updateResponse = try? UpdateSharingGroupResponse.decode(response) {
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
        
        let request = RemoveUserFromSharingGroupRequest()
        request.masterVersion = masterVersion
        request.sharingGroupUUID = sharingGroupUUID
        
        guard request.valid(), let parameters = request.urlParameters() else {
            completion(.error(SyncServerError.couldNotCreateRequest))
            return
        }
        
        let endpoint = ServerEndpoints.removeUserFromSharingGroup
        let serverURL = makeURL(forEndpoint: endpoint, parameters: parameters)
        
        sendRequestUsing(method: endpoint.method, toURL: serverURL, retryIfError: false) { (response, httpStatus, error) in

            if httpStatus == HTTPStatus.ok.rawValue, let response = response,
                let removeResponse = try? RemoveUserFromSharingGroupResponse.decode(response) {
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
    func serverNetworkingMinimumIOSAppVersion(forServerNetworking: Any?, version: ServerVersion) {
        if let syncServerDelegate = syncServerDelegate {
            EventDesired.reportEvent(.minimumIOSClientVersion(version), mask: desiredEvents, delegate: syncServerDelegate)
        }
    }
    
    func serverNetworkingFailover(forServerNetworking: Any?, message: String) {
        if let syncServerDelegate = syncServerDelegate {
            EventDesired.reportEvent(.serverDown(message: message), mask: desiredEvents, delegate: syncServerDelegate)
        }
    }
    
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

    public func registerPushNotificationToken(token: String, completion:((Error?)->())?) {
        let endpoint = ServerEndpoints.registerPushNotificationToken
        
        let registerPNToken = RegisterPushNotificationTokenRequest()
        registerPNToken.pushNotificationToken = token
        
        guard registerPNToken.valid() else {
            completion?(SyncServerError.couldNotCreateRequest)
            return
        }
        
        let parameters = registerPNToken.urlParameters()!
        let url = makeURL(forEndpoint: endpoint, parameters: parameters)

        sendRequestUsing(method: endpoint.method,
            toURL: url) { (response,  httpStatus, error) in
            
            let error = self.checkForError(statusCode: httpStatus, error: error)

            guard error == nil else {
                completion?(error)
                return
            }
            
            completion?(nil)
        }
    }
    
    func getSharingInvitationInfo(sharingInvitationUUID: String, completion:((Result<SyncServer.SharingInvitationInfo>)->(Void))?) {
        let endpoint = ServerEndpoints.getSharingInvitationInfo
        
        let getSharingInfoRequest = GetSharingInvitationInfoRequest()
        getSharingInfoRequest.sharingInvitationUUID = sharingInvitationUUID
        
        guard getSharingInfoRequest.valid() else {
            completion?(.error(SyncServerError.couldNotCreateRequest))
            return
        }
        
        let parameters = getSharingInfoRequest.urlParameters()!
        let url = makeURL(forEndpoint: endpoint, parameters: parameters)
        
        sendRequestUsing(method: endpoint.method, toURL: url) { (response,  httpStatus, error) in
            let resultError = self.checkForError(statusCode: httpStatus, error: error)
            
            if httpStatus == HTTPStatus.gone.rawValue {
                completion?(.success(.noInvitationFound))
                return
            }
            
            if resultError == nil {
                if let response = response,
                    let getSharingInvitationResponse = try? GetSharingInvitationInfoResponse.decode(response) {
                    let info = SyncServer.Invitation(code: sharingInvitationUUID, permission: getSharingInvitationResponse.permission, allowsSocialSharing: getSharingInvitationResponse.allowSocialAcceptance)
                    completion?(.success(.invitation(info)))
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
}

