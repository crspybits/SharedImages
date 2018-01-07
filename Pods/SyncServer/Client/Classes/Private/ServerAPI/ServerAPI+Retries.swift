//
//  ServerAPI+Retries.swift
//  Pods
//
//  Created by Christopher Prince on 6/17/17.
//
//

/* To test refresh failure: in "Other Swift Flags" in Xcode settings in the SyncServer pod define:

      TEST_REFRESH_FAILURE
 
    So far this is relevant to only the Shared Images app. This test requires that, when the Shared Images app first launches, it takes you to the images page. Then, try a refresh operation. A successful test outcome is that the user should be signed out and navigation should occur to the SignIn tab.
*/
import Foundation
import SMCoreLib
import SyncServer_Shared

private class RequestWithRetries {
    let maximumNumberRetries = 3
    
    let creds:GenericCredentials?
    let updateCreds:((_ creds:GenericCredentials?)->())
    let checkForError:(_ statusCode:Int?, _ error:SyncServerError?) -> SyncServerError?
    let desiredEvents:EventDesired!
    weak var delegate:SyncServerDelegate?
    
    private var triedToRefreshCreds = false
    private var numberTries = 0
    private var retryIfError:Bool

    var request:(()->())!
    var completionHandler:((_ error:SyncServerError?)->())!
    
    // When we get a 401 response from server.
    var userUnauthorized:(()->())!
    
    init(retryIfError:Bool = true, creds:GenericCredentials?, desiredEvents:EventDesired, delegate:SyncServerDelegate?, updateCreds:@escaping (_ creds:GenericCredentials?)->(), checkForError:@escaping (_ statusCode:Int?, _ error:SyncServerError?) -> SyncServerError?, userUnauthorized:@escaping ()->()) {
        self.creds = creds
        self.updateCreds = updateCreds
        self.checkForError = checkForError
        self.retryIfError = retryIfError
        self.desiredEvents = desiredEvents
        self.delegate = delegate
        self.userUnauthorized = userUnauthorized
    }
    
    deinit {
        Log.msg("deinit: RequestWithRetries")
    }
    
    // Make sure self.creds is non-nil before you call this!
    private func refreshCredentials(completion: @escaping (SyncServerError?) ->()) {
        EventDesired.reportEvent(.refreshingCredentials, mask: self.desiredEvents, delegate: self.delegate)
        self.creds!.refreshCredentials { error in
            if error == nil {
                self.updateCreds(self.creds)
            }
            
#if TEST_REFRESH_FAILURE
            completion(.testRefreshFailure)
#else
            completion(error)
#endif
        }
    }
    
    // Returns a duration in seconds.
    func exponentialFallbackDuration(forAttempt numberTimesTried:Int) -> TimeInterval {
        let duration = TimeInterval(pow(Float(numberTimesTried), 2.0))
        Log.msg("Will try operation again in \(duration) seconds")
        return duration
    }

    func exponentialFallback(forAttempt numberTimesTried:Int, completion:@escaping ()->()) {
        let duration = exponentialFallbackDuration(forAttempt: numberTimesTried)

        TimedCallback.withDuration(Float(duration)) {
            completion()
        }
    }
    
    private func completion(_ error:SyncServerError?) {
        completionHandler(error)
        
        // Get rid of circular reference so `RequestWithRetries` instance can be deallocated.
        completionHandler = nil
        request = nil
    }

    func retryCheck(statusCode:Int?, error:SyncServerError?) {
        numberTries += 1
        let errorCheck = checkForError(statusCode, error)
        
        if errorCheck == nil || numberTries >= maximumNumberRetries || !retryIfError {
            completion(errorCheck)
        }
        else if statusCode == HTTPStatus.unauthorized.rawValue {
            if triedToRefreshCreds || creds == nil {
                // unauthorized, but we're not refreshing. Cowardly give up.
                completion(error)
                userUnauthorized()
            }
            else {
                triedToRefreshCreds = true
                
                self.refreshCredentials() {[unowned self] error in
                    if error == nil {
                        // Success on refresh-- try request again.
                        // Not using `exponentialFallback` because we know that the issue arose due to an authorization error.
                        self.start()
                    }
                    else {
                        // Failed on refreshing creds-- not much point in going on.
                        self.completion(error)
                        self.userUnauthorized()
                    }
                }
            }
        }
        else {
            // We got an error, but it wasn't an authorization problem.
            // Let's make another try after waiting for a while.
            exponentialFallback(forAttempt: numberTries) {
                self.start()
            }
        }
    }
    
    func start() {
        request()
    }
}

// MARK: Wrapper over ServerNetworking calls to provide for error retries and credentials refresh.
extension ServerAPI {
    private func userUnauthorized() {
        delegate?.userWasUnauthorized(forServerAPI: self)
    }
    
    func sendRequestUsing(method: ServerHTTPMethod, toURL serverURL: URL, timeoutIntervalForRequest:TimeInterval? = nil, retryIfError retry:Bool=true, completion:((_ serverResponse:[String:Any]?, _ statusCode:Int?, _ error:SyncServerError?)->())?) {
        
        let rwr = RequestWithRetries(retryIfError: retry, creds:creds, desiredEvents:desiredEvents, delegate:syncServerDelegate, updateCreds: updateCreds, checkForError:checkForError, userUnauthorized: userUnauthorized)
        
        // I get rid of the circular references in the completion handler. These references are being used to retain the rwr object.
        rwr.request = {
            ServerNetworking.session.sendRequestUsing(method: method, toURL: serverURL, timeoutIntervalForRequest:timeoutIntervalForRequest) { (serverResponse, statusCode, error) in
                
                rwr.completionHandler = { error in
                    completion?(serverResponse, statusCode, error)
                }
                
#if TEST_REFRESH_FAILURE
                let theStatusCode:Int? = HTTPStatus.unauthorized.rawValue
#else
                let theStatusCode:Int? = statusCode
#endif

                rwr.retryCheck(statusCode: theStatusCode, error: error)
            }
        }
        rwr.start()
    }
    
    func upload(file: ServerNetworkingLoadingFile, fromLocalURL localURL: URL, toServerURL serverURL: URL, method: ServerHTTPMethod, completion:((_ urlResponse: HTTPURLResponse?, _ statusCode:Int?, _ error:SyncServerError?)->())?) {
        
        let rwr = RequestWithRetries(creds:creds, desiredEvents:desiredEvents, delegate:syncServerDelegate, updateCreds: updateCreds, checkForError:checkForError, userUnauthorized: userUnauthorized)
        
        // I get rid of the circular references in the completion handler. These references are being used to retain the rwr object.
        rwr.request = {
            ServerNetworking.session.upload(file: file, fromLocalURL: localURL, toServerURL: serverURL, method: method) { (serverResponse, statusCode, error) in
                
                rwr.completionHandler = { error in
                    completion?(serverResponse, statusCode, error)
                }
                rwr.retryCheck(statusCode: statusCode, error: error)
            }
        }
        rwr.start()
    }
    
    func download(file: ServerNetworkingLoadingFile, fromServerURL serverURL: URL, method: ServerHTTPMethod, completion:((SMRelativeLocalURL?, _ urlResponse:HTTPURLResponse?, _ statusCode:Int?, _ error:SyncServerError?)->())?) {
        
        let rwr = RequestWithRetries(creds:creds, desiredEvents:desiredEvents, delegate:syncServerDelegate, updateCreds: updateCreds, checkForError:checkForError, userUnauthorized: userUnauthorized)
        
        // I get rid of the circular references in the completion handler. These references are being used to retain the rwr object.
        rwr.request = {
            ServerNetworking.session.download(file: file, fromServerURL: serverURL, method: method) { (localURL, urlResponse, statusCode, error) in
                
                rwr.completionHandler = { error in
                    completion?(localURL, urlResponse, statusCode, error)
                }
                rwr.retryCheck(statusCode: statusCode, error: error)
            }
        }
        rwr.start()
    }
}
