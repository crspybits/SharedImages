//
//  ServerNetworking+Loading.swift
//  SyncServer
//
//  Created by Christopher Prince on 5/29/17.
//
//

// Loading = Uploading & Downloading
// This class relies on Core Data.

import Foundation
import SMCoreLib
import SyncServer_Shared

// The reason for this class is given here: https://stackoverflow.com/questions/44224048/timeout-issue-when-downloading-from-aws-ec2-to-ios-app
// 12/31/17; Plus, I want downloading and uploading to work in the background-- see https://github.com/crspybits/SharedImages/issues/36 (See that link for ideas about how to extend current background task operation).

typealias DownloadCompletion = (SMRelativeLocalURL?, HTTPURLResponse?, _ statusCode:Int?, SyncServerError?)->()
typealias UploadCompletion = (HTTPURLResponse?, _ statusCode:Int?, SyncServerError?)->()

private enum CompletionHandler {
    case download(DownloadCompletion)
    case upload(UploadCompletion)
}

struct ServerNetworkingLoadingFile {
    let fileUUID:String
    let fileVersion: FileVersionInt
}

class ServerNetworkingLoading : NSObject {
    static private(set) var session = ServerNetworkingLoading()
    
    weak var delegate:ServerNetworkingDelegate?
    
    private var session:URLSession!
    fileprivate var completionHandlers = [URLSessionTask:CompletionHandler]()
    fileprivate var backgroundCompletionHandler:(()->())?

    private override init() {
        super.init()
        
        createURLSession()
        
        CoreDataSync.perform(sessionName: Constants.coreDataName) {
            NetworkCached.deleteOldCacheEntries()
        }
    }
    
    private func createURLSession() {
        let appBundleName = Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as! String
        
        // https://developer.apple.com/reference/foundation/urlsessionconfiguration/1407496-background
        let sessionConfiguration = URLSessionConfiguration.background(withIdentifier: "biz.SpasticMuffin.SyncServer." + appBundleName)
        
        session = URLSession(configuration: sessionConfiguration, delegate: self, delegateQueue: OperationQueue.main)
    }
    
    // When I use this in testing, I get a crash. "*** Terminating app due to uncaught exception 'NSGenericException', reason: 'Task created in a session that has been invalidated'" See also https://stackoverflow.com/questions/20019692/nsurlsession-invalidateandcancel-bad-access
    func invalidateURLSession() {
        session.invalidateAndCancel()
        
        // That session is invalid now. Create another.
        createURLSession()
    }
    
    func appLaunchSetup() {
        // Don't need do anything. The init did it all. This method is just here as a reminder and a means to set up the session when the app launches.
    }
    
    func application(_ application: UIApplication, handleEventsForBackgroundURLSession identifier: String, completionHandler: @escaping () -> Void) {
        self.backgroundCompletionHandler = completionHandler
        DebugWriter.session.log("handleEventsForBackgroundURLSession")
    }
    
    // The caller must keep a strong reference to the returned object until at least all of the relevant ServerNetworkingDownloadDelegate delegate methods have been called upon completion of the download.
    private func downloadFrom(_ serverURL: URL, method: ServerHTTPMethod, andStart start:Bool=true) -> URLSessionDownloadTask {
        var request = URLRequest(url: serverURL)
        request.httpMethod = method.rawValue.uppercased()
        
        request.allHTTPHeaderFields = delegate?.serverNetworkingHeaderAuthentication(
                forServerNetworking: self)
        
        Log.msg("downloadFrom: serverURL: \(serverURL)")
        
        let downloadTask = session.downloadTask(with: request)
        
        if start {
            downloadTask.resume()
        }
        
        return downloadTask
    }
    
    private func uploadTo(_ serverURL: URL, file localURL: URL, method: ServerHTTPMethod, andStart start:Bool=true) -> URLSessionUploadTask {
    
        // It appears that `session.uploadTask` has a problem with relative URL's. I get "NSURLErrorDomain Code=-1 "unknown error" if I pass one of these. Make sure the URL is not relative.
        let uploadFilePath = localURL.path
        let nonRelativeUploadURL = URL(fileURLWithPath: uploadFilePath)
        
        var request = URLRequest(url: serverURL)
        request.httpMethod = method.rawValue.uppercased()
        
        request.allHTTPHeaderFields = delegate?.serverNetworkingHeaderAuthentication(
                forServerNetworking: self)
        
        Log.msg("uploadTo: serverURL: \(serverURL); localURL: \(nonRelativeUploadURL)")
        
        let uploadTask = session.uploadTask(with: request, fromFile: nonRelativeUploadURL)
        
        if start {
            uploadTask.resume()
        }
        
        return uploadTask
    }
    
    // Start off by assuming we're going to lose the handler because the app moves into the background -- cache the upload or download.
    fileprivate func makeCache(file:ServerNetworkingLoadingFile, serverURL: URL) {
        CoreDataSync.perform(sessionName: Constants.coreDataName) {
            let cachedResults = NetworkCached.newObject() as! NetworkCached
            
            // These serve as a key back to the client's info.
            cachedResults.fileUUID = file.fileUUID
            cachedResults.fileVersion = file.fileVersion
            
            // This is going to serve as a key -- so that when the results come back from the server, we can lookup the cache object.
            cachedResults.serverURLKey = serverURL.absoluteString
            
            cachedResults.save()
        }
    }
    
    fileprivate func cacheResult(serverURLKey: URL, response:HTTPURLResponse, localURL: SMRelativeLocalURL? = nil) {
        CoreDataSync.perform(sessionName: Constants.coreDataName) {
            guard let cache = NetworkCached.fetchObjectWithServerURLKey(serverURLKey.absoluteString) else {
                return
            }
            
            if let localURL = localURL {
                cache.downloadURL = localURL
            }
            
            cache.dateTimeCached = Date() as NSDate
            cache.httpResponse = response
            cache.save()
        }
    }
    
    fileprivate func lookupAndRemoveCache(file:ServerNetworkingLoadingFile, download: Bool) -> (HTTPURLResponse, SMRelativeLocalURL?)? {
        
        var result:(HTTPURLResponse, SMRelativeLocalURL?)?
        
        CoreDataSync.perform(sessionName: Constants.coreDataName) {
            guard let fetchedCache = NetworkCached.fetchObjectWithUUID(file.fileUUID, andVersion: file.fileVersion, download: download) else {
                return
            }
            
            var resultCache:NetworkCached?
            
            if download {
                if fetchedCache.downloadURL != nil {
                    resultCache = fetchedCache
                }
            }
            else {
                resultCache = fetchedCache
            }
            
            if let response = resultCache?.httpResponse {
                result = (response, resultCache?.downloadURL)
                CoreData.sessionNamed(Constants.coreDataName).remove(resultCache!)
                CoreData.sessionNamed(Constants.coreDataName).saveContext()
            }
        }
        
        return result
    }
    
    fileprivate func removeCache(serverURLKey: URL) {
        CoreDataSync.perform(sessionName: Constants.coreDataName) {
            guard let cache = NetworkCached.fetchObjectWithServerURLKey(serverURLKey.absoluteString) else {
                Log.error("Could not find NetworkCached object for serverURLKey: \(serverURLKey)")
                return
            }
            
            CoreData.sessionNamed(Constants.coreDataName).remove(cache)
            CoreData.sessionNamed(Constants.coreDataName).saveContext()
        }
    }
    
    // In both of the following methods, the `ServerNetworkingLoadingFile` is redundant with the info in the serverURL, but is needed for caching purposes.
    
    // The file reference in the URL given in the completion handler has already been transferred to a more permanent location.
    func download(file:ServerNetworkingLoadingFile, fromServerURL serverURL: URL, method: ServerHTTPMethod, completion:@escaping DownloadCompletion) {
    
        // Before we go any further-- check to see if we have cached results.
        // There is a race condition here: What if we have a cached object, but the upload hasn't finished yet?? Need to fix this. See https://github.com/crspybits/SharedImages/issues/72
        if let (response, url) = lookupAndRemoveCache(file: file, download: true) {
            let statusCode = response.statusCode
            DebugWriter.session.log("Using cached download result")
            
            // We are not caching error results, so set the error to nil.
            completion(url, response, statusCode, nil)
            return
        }
        
        makeCache(file: file, serverURL: serverURL)
        
        let task = downloadFrom(serverURL, method: method, andStart:false)
        Synchronized.block(self) {
            completionHandlers[task] = .download(completion)
        }
        task.resume()
    }
    
    func upload(file:ServerNetworkingLoadingFile, fromLocalURL localURL: URL, toServerURL serverURL: URL, method: ServerHTTPMethod, completion:@escaping UploadCompletion) {
    
        // Before we go any further-- check to see if we have cached results.
        // There is a race condition here: What if we have a cached object, but the upload hasn't finished yet?? Need to fix this. See https://github.com/crspybits/SharedImages/issues/72
        if let (response, _) = lookupAndRemoveCache(file: file, download: false) {
            let statusCode = response.statusCode
            DebugWriter.session.log("Using cached upload result")
            // We are not caching error results, so set the error to nil.
            completion(response, statusCode, nil)
            return
        }
    
        makeCache(file: file, serverURL: serverURL)

        let task = uploadTo(serverURL, file: localURL, method: method, andStart:false)
        Synchronized.block(self) {
            completionHandlers[task] = .upload(completion)
        }
        task.resume()
    }
}

extension ServerNetworkingLoading : URLSessionDelegate, URLSessionTaskDelegate, URLSessionDownloadDelegate, URLSessionDataDelegate {

#if SELF_SIGNED_SSL
    public func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Swift.Void) {
        completionHandler(URLSession.AuthChallengeDisposition.useCredential, URLCredential(trust: challenge.protectionSpace.serverTrust!))
    }
#endif

#if BACKGROUND_TASKS_TESTS
    // 1/7/18; Yes, this is a hack. If `pathFromCaches` path changes, this will break. However, I'm only using this in testing. I'm doing this in no small part because right now I'm not able to get the XCTests to work on an actual device. Argh.
    func convertToCurrentCachesDirectory(originalURL: URL) -> URL {
        let fileName = originalURL.lastPathComponent
    
        let pathFromCaches = "/com.apple.nsurlsessiond/Downloads/biz.SpasticMuffin.SyncServer/"
        let cachesDirs: [String] = NSSearchPathForDirectoriesInDomains(.cachesDirectory, .allDomainsMask, true)
        let filePath = cachesDirs[0] + pathFromCaches + fileName
        return URL(fileURLWithPath: filePath)
    }
#endif

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
    
        var originalDownloadLocation:URL!
        originalDownloadLocation = location
        
#if BACKGROUND_TASKS_TESTS
       originalDownloadLocation = convertToCurrentCachesDirectory(originalURL: location)
#endif

        Log.msg("download completed: location: \(originalDownloadLocation);  status: \(String(describing: (downloadTask.response as? HTTPURLResponse)?.statusCode))")

        let originalRequestURL = downloadTask.originalRequest!.url!
        var returnError:SyncServerError?

        let movedDownloadedFile = FilesMisc.createTemporaryRelativeFile()

        // Transfer the temporary file to a more permanent location. Have to do it right now. https://developer.apple.com/reference/foundation/urlsessiondownloaddelegate/1411575-urlsession
        if movedDownloadedFile == nil {
            returnError = .couldNotCreateNewFile
        }
        else {
            do {
                _ = try FileManager.default.replaceItemAt(movedDownloadedFile! as URL, withItemAt: originalDownloadLocation)
            }
            catch (let error) {
                Log.error("Could not move file: \(error)")
                returnError = .couldNotMoveDownloadFile
            }
        }
        
        // With an HTTP or HTTPS request, we get HTTPURLResponse back. See https://developer.apple.com/reference/foundation/urlsession/1407613-datatask
        let response = downloadTask.response as? HTTPURLResponse
        if response == nil {
            returnError = .couldNotGetHTTPURLResponse
        }
        
        var handler:CompletionHandler?
        Synchronized.block(self) {
            handler = completionHandlers[downloadTask]
        }
        
        if case .download(let completion)? = handler {
            removeCache(serverURLKey: originalRequestURL)
            completion(movedDownloadedFile, response, response?.statusCode, returnError)
        }
        else {
            // Must be running in the background-- since we don't have a handler.
            // We are not caching error results. Why bother? If we don't cache a result, the download will just need to be done again. And since there is an error, the download *will* need to be done again.
            if returnError == nil {
                cacheResult(serverURLKey:originalRequestURL, response: response!, localURL: movedDownloadedFile!)
                DebugWriter.session.log("Caching download result")
            }
        }
        
        Log.msg("Number of completion handlers in dictionary (start): \(completionHandlers.count)")
    }
    
    // For downloads: This gets called even when there was no error, but I believe only it (and not the `didFinishDownloadingTo` method) gets called if there is an error.
    // For uploads: This gets called to indicate successful completion or an error.
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        let response = task.response as? HTTPURLResponse
        Log.msg("didCompleteWithError: \(String(describing: error)); status: \(String(describing: response?.statusCode))")
        
        var handler:CompletionHandler?
        Synchronized.block(self) {
            handler = completionHandlers[task]
            completionHandlers[task] = nil
        }
        
        Log.msg("Number of completion handlers remaining in dictionary: \(completionHandlers.count)")
    
        if error != nil {
            Log.msg("didCompleteWithError: \(String(describing: error)); status: \(String(describing: response?.statusCode))")
        }
        
        let originalRequestURL = task.originalRequest!.url!

        switch handler {
        case .none:
            // No handler. We must be running in the background. Ignore errors.
            if error == nil {
                switch task {
                case is URLSessionUploadTask:
                    cacheResult(serverURLKey: originalRequestURL, response: response!)
                    DebugWriter.session.log("Caching upload result")
                case is URLSessionDownloadTask:
                    // We will have already cached this.
                    break
                default:
                    // Should never get here!
                    break
                }
            }
        case .some(.download(let completion)):
            // Only need to call completion handler for a download if we have an error. In the normal case, we've already called it.
            if error != nil {
                removeCache(serverURLKey: originalRequestURL)
                completion(nil, response, response?.statusCode, .urlSessionError(error!))
            }
        case .some(.upload(let completion)):
            removeCache(serverURLKey: originalRequestURL)

            // For uploads, since this is called if we get an error or not, we always have to call the completion handler.
            let errorResult = error == nil ? nil : SyncServerError.urlSessionError(error!)
            completion(response, response?.statusCode, errorResult)
        }
    }
    
    // Apparently the following delegate method is how we get back body data from an upload task: "When the upload phase of the request finishes, the task behaves like a data task, calling methods on the session delegate to provide you with the server’s response—headers, status code, content data, and so on." (see https://developer.apple.com/documentation/foundation/nsurlsessionuploadtask).
    // But, how do we coordinate the status code and error info, apparently received in didCompleteWithError, with this??
    // 1/2/18; Because of this issue I've just now changed how the server upload response gives it's results-- the values now come back in an HTTP header key, just like the download.
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
    }
    
    // This gets called "When all events have been delivered, the system calls the urlSessionDidFinishEvents(forBackgroundURLSession:) method of URLSessionDelegate. At this point, fetch the backgroundCompletionHandler stored by the app delegate in Listing 3 and execute it. Listing 4 shows this process." (https://developer.apple.com/documentation/foundation/url_loading_system/downloading_files_in_the_background)
    func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
        // "Note that because urlSessionDidFinishEvents(forBackgroundURLSession:) may be called on a secondary queue, it needs to explicitly execute the handler (which was received from a UIKit method) on the main queue." (https://developer.apple.com/documentation/foundation/url_loading_system/downloading_files_in_the_background)
        
        DebugWriter.session.log("urlSessionDidFinishEvents")
        
        Thread.runSync(onMainThread: {[unowned self] in
            self.backgroundCompletionHandler?()
            self.backgroundCompletionHandler = nil
        })
    }
    
    func urlSession(_ session: URLSession, didBecomeInvalidWithError error: Error?) {
        Log.error("urlSession didBecomeInvalidWithError: \(String(describing: error))")
    }
}
