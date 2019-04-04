//
//  ServerConstants.swift
//  Authentication
//
//  Created by Christopher Prince on 11/26/16.
//
//

import Foundation

// These are shared with client apps

public class ServerConstants {
    // Generic HTTP request header authentication keys; the values for these keys are duplicated from Kitura (they didn't give named constants).
    public static let XTokenTypeKey = "X-token-type"
    public static let HTTPOAuth2AccessTokenKey = "access_token"
    
    // HTTP request header keys specific to Google
    @available(*, deprecated, message: "Use: HTTPOAuth2AuthorizationCodeKey")
    public static let GoogleHTTPServerAuthCodeKey = "SyncServer-Google-server-auth-code"

    // OAuth2 authorization code, e.g., from Google
    public static let HTTPOAuth2AuthorizationCodeKey = "SyncServer-authorization-code"
    
    // Necessary for some authorization systems, e.g., Dropbox.
    public static let HTTPAccountIdKey = "X-account-id"

#if DEBUG
    // Give this key any string value to test failing of an endpoint.
    public static let httpRequestEndpointFailureTestKey = "SyncServer-FailureTest"
#endif
    
    // HTTP: request header key
    // Since the Device-UUID is a somewhat secure identifier, I'm passing it in the HTTP header. Plus, it makes the device UUID available early in request processing.
    public static let httpRequestDeviceUUID = "SyncServer-Device-UUID"
    
    // HTTP response header keys
    // 9/9/17; Keep these header keys in *lower case* to be compatible with NGNIX-- which sends them back in lower case.
    
    // Used when downloading a file to return parameters (as a HTTP header response header).
    public static let httpResponseMessageParams = "syncserver-message-params"

    // Used for some Account types (e.g., Facebook)
    public static let httpResponseOAuth2AccessTokenKey = "syncserver-access-token"
    
    // The value of this key is a "X.Y.Z" version string.
    public static let httpResponseCurrentServerVersion = "syncserver-version"

    // If present, the value of this key is a "X.Y.Z" version string. This is intended to be the minimum version of the *client* app not the SyncServer iOS client interface (i.e., not https://github.com/crspybits/SyncServer-iOSClient).
    public static let httpResponseMinimumIOSClientAppVersion = "syncserver-minimum-ios-client-app-version"

    public enum AuthTokenType : String {
        case GoogleToken
        case FacebookToken
        case DropboxToken
        
        public func toCloudStorageType() -> CloudStorageType? {
            switch self {
            case .DropboxToken:
                return .Dropbox
            case .GoogleToken:
                return .Google
            case .FacebookToken:
                return nil
            }
        }
    }
    
    public static let maxNumberSharingInvitationAcceptors:UInt = 10
    
    // 60 seconds/minute * 60 minutes/hour * 24 hours/day == seconds/day
    public static let sharingInvitationExpiryDuration:TimeInterval = 60*60*24 // 1 day
}




