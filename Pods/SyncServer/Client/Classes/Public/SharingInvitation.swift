//
//  SharingInvitation.swift
//  Spastic Muffin, LLC.
//
//  Created by Christopher Prince on 4/17/17.
//
//

import Foundation
import SMCoreLib
import SyncServer_Shared

public protocol SharingInvitationDelegate : class {
func sharingInvitationReceived(_ sharingInvitation:SharingInvitation)
}

public class SharingInvitation {
    private static let queryItemAuthorizationCode = "code"
    private static let queryItemPermission = "permission"

    public static let session = SharingInvitation()
    
    public weak var delegate:SharingInvitationDelegate?
    
    public var sharingInvitationCode:String?
    
    // It seems odd to have this coming in as a URL parameter, but it has no effect on the permissions granted. Rather, it's here for the UI-- to tell the invited person what kind of permissions they would get if they accept the invitation. (The alternative would be to have a dedicated backend call which would return the sharing permission given the invitation code).
    public var sharingInvitationPermission:SharingPermission?

    // The upper/lower case sense of this is ignored.
    static let urlScheme = SMIdentifiers.session().APP_BUNDLE_IDENTIFIER() + ".invitation"
    
    private init() {
    }
    
    // This URL/String is suitable for sending in an email to the person being invited.
    // Handles urls of the form: 
    //      <BundleId>.invitation://?code=<InvitationCode>&permission=<permission>
    //      where <BundleId> is something like biz.SpasticMuffin.SharedNotes
    //
    public static func createSharingURL(invitationCode:String, permission:SharingPermission) -> String {
        let urlString = self.urlScheme + "://?\(queryItemAuthorizationCode)=" + invitationCode + "&\(queryItemPermission)=" + permission.rawValue
        return urlString
    }
    
    // Returns true iff can handle the url.
    public func application(_ app: UIApplication, open url: URL, options: [UIApplicationOpenURLOptionsKey : Any] = [:]) -> Bool {
        Log.msg("url: \(url)")
        
#if false
        Alert.show(withTitle: "SharingInvitation", message: "url: \(url)")
#endif
        
        var returnResult = false
        
        // Use case insensitive comparison because the incoming url scheme will be lower case.
        if url.scheme!.caseInsensitiveCompare(SharingInvitation.urlScheme) == ComparisonResult.orderedSame {
            if let components = URLComponents(url: url, resolvingAgainstBaseURL: false) {
                Log.msg("components.queryItems: \(String(describing: components.queryItems))")
                
                if components.queryItems != nil && components.queryItems!.count == 2 {
                    var code:String?
                    var permission:SharingPermission?
                    
                    let queryItemCode = components.queryItems![0]
                    if queryItemCode.name == SharingInvitation.queryItemAuthorizationCode && queryItemCode.value != nil  {
                        Log.msg("queryItemCode.value: \(queryItemCode.value!)")
                        code = queryItemCode.value!
                    }
                    
                    let queryItemPermission = components.queryItems![1]
                    if queryItemPermission.name == SharingInvitation.queryItemPermission && queryItemPermission.value != nil  {
                        Log.msg("queryItemPermission.value: \(queryItemPermission.value!)")
                        permission = SharingPermission(rawValue: queryItemPermission.value!)
                    }
                    
#if false
                    Alert.show(withTitle: "SharingInvitation", message: "code: \(String(describing: code)); permission: \(String(describing: permission)); delegate: \(String(describing: delegate))")
#endif
                    
                    if code != nil && permission != nil {
                        sharingInvitationCode = code
                        sharingInvitationPermission = permission
                        returnResult = true
                        self.delegate?.sharingInvitationReceived(self)
                    }
                }
            }
        }

        return returnResult
    }
}
