//
//  ServerNetworking.swift
//  SyncServer
//
//  Created by Christopher Prince on 11/29/15.
//  Copyright © 2015 Christopher Prince. All rights reserved.
//

import Foundation
import SMCoreLib
import SyncServer_Shared

protocol ServerNetworkingAuthentication : class {
    // Key/value pairs to be added to the outgoing HTTP header for authentication
    func headerAuthentication(forServerNetworking: Any?) -> [String:String]?
}

enum DownloadFromError : Error {
case couldNotGetHTTPURLResponse
case didNotGetURL
case couldNotMoveFile
case couldNotCreateNewFile
}

class ServerNetworking : NSObject {
    static let session = ServerNetworking()
    
    private weak var _authenticationDelegate:ServerNetworkingAuthentication?

    var authenticationDelegate:ServerNetworkingAuthentication? {
        get {
            return _authenticationDelegate
        }
        set {
            ServerNetworkingDownload.session.authenticationDelegate = newValue
            _authenticationDelegate = newValue
        }
    }
    
    func appLaunchSetup() {
        // TODO: *3* How can I have a networking spinner in the status bar? See https://github.com/crspybits/SyncServer-iOSClient/issues/7
    }

    enum ServerNetworkingError : Error {
    case noNetworkError
    }
    
    func sendRequestUsing(method: ServerHTTPMethod, toURL serverURL: URL, timeoutIntervalForRequest:TimeInterval? = nil,
        completion:((_ serverResponse:[String:Any]?, _ statusCode:Int?, _ error:Error?)->())?) {
        
        sendRequestTo(serverURL, method: method, timeoutIntervalForRequest:timeoutIntervalForRequest) { (serverResponse, statusCode, error) in
            completion?(serverResponse, statusCode, error)
        }
    }
    
    enum PostUploadDataToError : Error {
    case ErrorConvertingServerResponseToJsonDict
    case CouldNotGetHTTPURLResponse
    }
    
    // Data is sent in the body via a POST request (not multipart).
    func postUploadDataTo(_ serverURL: URL, dataToUpload:Data, completion:((_ serverResponse:[String:Any]?, _ statusCode:Int?, _ error:Error?)->())?) {

        guard Network.session().connected() else {
            completion?(nil, nil, ServerNetworkingError.noNetworkError)
            return
        }
        
        let sessionConfiguration = URLSessionConfiguration.default
        sessionConfiguration.httpAdditionalHeaders = self.authenticationDelegate?.headerAuthentication(forServerNetworking: self)
        
        // COULD DO: Use a delegate here to track upload progress.
        let session = URLSession(configuration: sessionConfiguration, delegate: self, delegateQueue: nil)
        
        // COULD DO: Data uploading task. We could use NSURLSessionUploadTask instead of NSURLSessionDataTask if we needed to support uploads in the background
        
        var request = URLRequest(url: serverURL)
        request.httpMethod = "POST"
        request.httpBody = dataToUpload
        
        Log.msg("postUploadDataTo: serverURL: \(serverURL)")
        
        let uploadTask:URLSessionUploadTask = session.uploadTask(with: request, from: dataToUpload) { (data, urlResponse, error) in            
            self.processResponse(data: data, urlResponse: urlResponse, error: error, completion: completion)
        }
        
        uploadTask.resume()
    }
    
    public func downloadFrom(_ serverURL: URL, method: ServerHTTPMethod, completion:((SMRelativeLocalURL?, _ serverResponse:HTTPURLResponse?, _ statusCode:Int?, _ error:Error?)->())?) {

        guard Network.session().connected() else {
            completion?(nil, nil, nil, ServerNetworkingError.noNetworkError)
            return
        }
        
        ServerNetworkingDownload.session.downloadFrom(serverURL, method: method) { (url, urlResponse, status, error) in
        
            if error == nil {
                guard url != nil else {
                    completion?(nil, nil, urlResponse?.statusCode, DownloadFromError.didNotGetURL)
                    return
                }
            }

            completion?(url, urlResponse, urlResponse?.statusCode, error)
        }
    }
    
    private func sendRequestTo(_ serverURL: URL, method: ServerHTTPMethod, dataToUpload:Data? = nil, timeoutIntervalForRequest:TimeInterval? = nil, completion:((_ serverResponse:[String:Any]?, _ statusCode:Int?, _ error:Error?)->())?) {
    
        guard Network.session().connected() else {
            completion?(nil, nil, ServerNetworkingError.noNetworkError)
            return
        }
    
        let sessionConfiguration = URLSessionConfiguration.default
        if timeoutIntervalForRequest != nil {
            sessionConfiguration.timeoutIntervalForRequest = timeoutIntervalForRequest!
        }
        
        sessionConfiguration.httpAdditionalHeaders = self.authenticationDelegate?.headerAuthentication(forServerNetworking: self)
        Log.msg("httpAdditionalHeaders: \(String(describing: sessionConfiguration.httpAdditionalHeaders))")
        
        // If needed, use a delegate here to track upload progress.
        let session = URLSession(configuration: sessionConfiguration, delegate: self, delegateQueue: nil)
        
        // Data uploading task. We could use NSURLSessionUploadTask instead of NSURLSessionDataTask if we needed to support uploads in the background
        
        var request = URLRequest(url: serverURL)
        request.httpMethod = method.rawValue.uppercased()
        request.httpBody = dataToUpload
        
        Log.msg("sendRequestTo: serverURL: \(serverURL)")
        
        let uploadTask:URLSessionDataTask = session.dataTask(with: request) { (data, urlResponse, error) in
            self.processResponse(data: data, urlResponse: urlResponse, error: error, completion: completion)
        }
        
        uploadTask.resume()
    }
    
    private func processResponse(data:Data?, urlResponse:URLResponse?, error: Error?, completion:((_ serverResponse:[String:Any]?, _ statusCode:Int?, _ error:Error?)->())?) {
        if error == nil {
            // With an HTTP or HTTPS request, we get HTTPURLResponse back. See https://developer.apple.com/reference/foundation/urlsession/1407613-datatask
            guard let response = urlResponse as? HTTPURLResponse else {
                completion?(nil, nil, PostUploadDataToError.CouldNotGetHTTPURLResponse)
                return
            }
            
            // Treating unauthorized specially because we attempt a credentials refresh in some cases when we get this.
            if response.statusCode == HTTPStatus.unauthorized.rawValue {
                completion?(nil, response.statusCode, nil)
                return
            }
            
            var json:Any?
            do {
                try json = JSONSerialization.jsonObject(with: data!, options: JSONSerialization.ReadingOptions(rawValue: UInt(0)))
            } catch (let error) {
                Log.error("processResponse: Error in JSON conversion: \(error); statusCode= \(response.statusCode)")
                completion?(nil, response.statusCode, error)
                return
            }
            
            guard let jsonDict = json as? [String: Any] else {
                completion?(nil, response.statusCode, PostUploadDataToError.ErrorConvertingServerResponseToJsonDict)
                return
            }
            
            var resultDict = jsonDict
            
            // Some responses (from endpoints doing sharing operations) have ServerConstants.httpResponseOAuth2AccessTokenKey in their header. Pass it up using the same key.
            if let accessTokenResponse = response.allHeaderFields[ServerConstants.httpResponseOAuth2AccessTokenKey] {
                resultDict[ServerConstants.httpResponseOAuth2AccessTokenKey] = accessTokenResponse
            }
            
            Log.msg("No errors on upload: jsonDict: \(jsonDict)")
            completion?(resultDict, response.statusCode, nil)
        }
        else {
            completion?(nil, nil, error)
        }
    }
}

extension ServerNetworking : URLSessionDelegate {
#if SELF_SIGNED_SSL
    public func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Swift.Void) {
        completionHandler(URLSession.AuthChallengeDisposition.useCredential, URLCredential(trust: challenge.protectionSpace.serverTrust!))
    }
#endif
}
