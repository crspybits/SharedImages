//
//  URL+Extras.swift
//  SMLinkPreview
//
//  Created by Christopher G Prince on 4/23/19.
//

import Foundation

extension URL {
    // Get rid of the scheme (e.g., https://) on the URL
    func urlWithoutScheme() -> String? {
        guard let formattedURL = (self as NSURL).resourceSpecifier,
            formattedURL.count > 2 else {
            return nil
        }
        
        // Remove the two slashes left after the resourceSpecifier call.
        return String(formattedURL.dropFirst().dropFirst())
    }
    
    enum ForceScheme: String {
        case https
        case http
        
    }
    
    // Returns the URL unchanged at least in the case if the scheme is "file" for a reference to a local file.
    func attemptForceScheme(_ forceScheme:ForceScheme?) -> URL {
        guard let forceScheme = forceScheme else {
            return self
        }
        
        guard var components = URLComponents(url: self, resolvingAgainstBaseURL: true) else {
            return self
        }
        
        if components.scheme == "file" {
            return self
        }
        
        components.scheme = forceScheme.rawValue
        if let url = components.url {
            return url
        }
        else {
            return self
        }
    }
}
