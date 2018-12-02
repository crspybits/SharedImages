//
//  ServerResponseCheck.swift
//  SyncServer
//
//  Created by Christopher G Prince on 12/1/18.
//

import Foundation
import SyncServer_Shared

class ServerResponseCheck {
    var failoverMessageURL: URL?
    weak var delegate:ServerNetworkingDelegate?

    private init() {}
    static let session = ServerResponseCheck()
    
    private func getFailoverMessage(completion: @escaping (_ message: String?)->()) {
        guard let failoverURL = self.failoverMessageURL else {
            completion(nil)
            return
        }
        
        let config = URLSessionConfiguration.default
        let session = URLSession(configuration: config)
        let task = session.downloadTask(with: failoverURL) { url, urlResponse, error in
            guard let url = url, error == nil,
                let data = try? Data(contentsOf: url),
                let string = String(data: data, encoding: .utf8) else {
                completion(nil)
                return
            }
            
            completion(string)
        }
        
        task.resume()
    }
    
    // Call this if you get a serviceUnavailable HTTP response.
    func failover(completion: @escaping ()->()) {
        getFailoverMessage() { message in
            if let message = message {
                self.delegate?.serverNetworkingFailover(forServerNetworking: self, message: message)
            }
            
            completion()
        }
    }
    
    func minimumIOSClientVersion(response: HTTPURLResponse) {
        if let iosAppVersionRaw = response.allHeaderFields[
            ServerConstants.httpResponseMinimumIOSClientAppVersion] as? String,
            let iOSAppVersion = ServerVersion(rawValue: iosAppVersionRaw) {
            self.delegate?.serverNetworkingMinimumIOSAppVersion(forServerNetworking: self, version: iOSAppVersion)
        }
    }
}
