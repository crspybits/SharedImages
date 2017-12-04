//
//  ServerNetworking+Download.swift
//  SyncServer
//
//  Created by Christopher Prince on 5/29/17.
//
//

import Foundation
import SMCoreLib
import SyncServer_Shared

// The reason for this class is given here: https://stackoverflow.com/questions/44224048/timeout-issue-when-downloading-from-aws-ec2-to-ios-app

protocol ServerNetworkingDownloadDelegate : class {
    // The file reference in the URL given in serverNetworkingDownloadCompleted  has already been transferred to a more permanent location.
    func serverNetworkingDownloadCompleted(_ snd: ServerNetworkingDownload, url: SMRelativeLocalURL?, response: HTTPURLResponse?, statusCode:Int?, error: Error?)
}

typealias DownloadCompletion = (SMRelativeLocalURL?, HTTPURLResponse?, _ statusCode:Int?, Error?)->()

private class CompletionHandler {
    var completion:DownloadCompletion!
}

class ServerNetworkingDownload : NSObject {
    static let session = ServerNetworkingDownload()
    
    weak var delegate:ServerNetworkingDownloadDelegate?
    weak var authenticationDelegate:ServerNetworkingAuthentication?
    
    private var session:URLSession!
    fileprivate var completionHandlers = [URLSessionDownloadTask:CompletionHandler]()

    override init() {
        super.init()
        // https://developer.apple.com/reference/foundation/urlsessionconfiguration/1407496-background
        let sessionConfiguration = URLSessionConfiguration.background(withIdentifier: "biz.SpasticMuffin.SyncServer")
        
        session = URLSession(configuration: sessionConfiguration, delegate: self, delegateQueue: OperationQueue.main)
    }
    
    // The caller must keep a strong reference to the returned object until at least all of the relevant ServerNetworkingDownloadDelegate delegate methods have been called upon completion of the download.
    func downloadFrom(_ serverURL: URL, method: ServerHTTPMethod, andStart start:Bool=true) -> URLSessionDownloadTask {
        var request = URLRequest(url: serverURL)
        request.httpMethod = method.rawValue.uppercased()
        
        request.allHTTPHeaderFields = authenticationDelegate?.headerAuthentication(forServerNetworking: self)
        
        print("downloadFrom: serverURL: \(serverURL)")
        
        let downloadTask = session.downloadTask(with: request)
        
        if start {
            downloadTask.resume()
        }
        
        return downloadTask
    }
    
    // By-passes the use of the ServerNetworkingDownloadDelegate
    // The file reference in the URL given in the completion handler has already been transferred to a more permanent location.
    func downloadFrom(_ serverURL: URL, method: ServerHTTPMethod, completion:@escaping DownloadCompletion) {
        let handler = CompletionHandler()
        handler.completion = completion
        let task = downloadFrom(serverURL, method: method, andStart:false)
        completionHandlers[task] = handler
        task.resume()
    }
}

extension ServerNetworkingDownload : URLSessionDelegate, URLSessionTaskDelegate, URLSessionDownloadDelegate {

#if SELF_SIGNED_SSL
    public func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Swift.Void) {
        completionHandler(URLSession.AuthChallengeDisposition.useCredential, URLCredential(trust: challenge.protectionSpace.serverTrust!))
    }
#endif

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
    
        Log.msg("download completed: location: \(location);  status: \(String(describing: (downloadTask.response as? HTTPURLResponse)?.statusCode))")
        
        var newFileURL:SMRelativeLocalURL?
        newFileURL = FilesMisc.createTemporaryRelativeFile()
        var returnError:Error?
        
        // Transfer the temporary file to a more permanent location. Have to do it right now. https://developer.apple.com/reference/foundation/urlsessiondownloaddelegate/1411575-urlsession
        if newFileURL == nil {
            returnError = DownloadFromError.couldNotCreateNewFile
        }
        else {
            do {
                _ = try FileManager.default.replaceItemAt(newFileURL! as URL, withItemAt: location)
            }
            catch (let error) {
                Log.error("Could not move file: \(error)")
                returnError = DownloadFromError.couldNotMoveFile
            }
        }
        
        // With an HTTP or HTTPS request, we get HTTPURLResponse back. See https://developer.apple.com/reference/foundation/urlsession/1407613-datatask
        let response = downloadTask.response as? HTTPURLResponse
        if response == nil {
            returnError = DownloadFromError.couldNotGetHTTPURLResponse
        }
        
        if let handler = completionHandlers[downloadTask] {
            handler.completion(newFileURL, response, response?.statusCode, returnError)
        }
        else {
            self.delegate?.serverNetworkingDownloadCompleted(self, url: newFileURL, response: response, statusCode: response?.statusCode, error: returnError)
        }
        
        Log.msg("Number of completion handlers in dictionary (start): \(completionHandlers.count)")
    }
    
    // This gets called even when there was no error, but I believe only it (and not the `didFinishDownloadingTo` method) gets called if there is an error.
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {

        let response = task.response as? HTTPURLResponse
        
        var handler:CompletionHandler?
        if let downloadTask = task as? URLSessionDownloadTask {
            handler = completionHandlers[downloadTask]
            completionHandlers[downloadTask] = nil
        }
        
        Log.msg("Number of completion handlers in dictionary (end): \(completionHandlers.count)")
        
        if error == nil {
            Log.msg("didCompleteWithError: \(String(describing: error)); status: \(String(describing: response?.statusCode))")
        }
        else {
            Log.error("didCompleteWithError: \(String(describing: error)); status: \(String(describing: response?.statusCode))")

            if handler == nil {
                self.delegate?.serverNetworkingDownloadCompleted(self, url: nil, response: response, statusCode: response?.statusCode, error: error)
            }
            else {
                handler!.completion(nil, response, response?.statusCode, error)
            }
        }
    }
}
