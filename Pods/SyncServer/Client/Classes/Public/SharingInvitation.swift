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
    func sharingInvitationReceived(_ invite:SyncServer.Invitation)
}

public class SharingInvitation {    
    private var invitation:SyncServer.Invitation?
    
    private static let queryItemAuthorizationCode = "code"

    public static let session = SharingInvitation()
    
    public weak var delegate:SharingInvitationDelegate?
    
    // The upper/lower case sense of this is ignored.
    static let urlScheme = SMIdentifiers.session().APP_BUNDLE_IDENTIFIER() + ".invitation"
    
    private init() {
    }
    
    /**
        This to deal with the case where the delegate method of this class wasn't set before the invitation was received. See https://github.com/crspybits/SharedImages/issues/42
 
        This will be nil if the invitation has already been processed by the delegate. If it returns non-nil, it returns non-nil only once for that invitation.
    */
    public func receive() -> SyncServer.Invitation? {
        let result = invitation
        invitation = nil
        return result
    }
    
    /**
        This URL/String is suitable for sending in an email to the person being invited.
     
        Handles urls of the form:
          <BundleId>.invitation://?code=<InvitationCode>
          where <BundleId> is something like biz.SpasticMuffin.SharedImages
    */
    public static func createSharingURL(invitationCode:String) -> String {
        let urlString = self.urlScheme + "://?\(queryItemAuthorizationCode)=" + invitationCode
        return urlString
    }
    
    /// Returns true iff can handle the url.
    public func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
        Log.msg("url: \(url)")
        
#if false
        Alert.show(withTitle: "SharingInvitation", message: "url: \(url)")
#endif
        
        var returnResult = false
        
        // Use case insensitive comparison because the incoming url scheme will be lower case.
        if url.scheme!.caseInsensitiveCompare(SharingInvitation.urlScheme) == ComparisonResult.orderedSame {
            if let components = URLComponents(url: url, resolvingAgainstBaseURL: false) {
                Log.msg("components.queryItems: \(String(describing: components.queryItems))")
                
                // 4/10/19; Keeping the count check as >= 1 to be backward compatible with the older style which included permission.
                if components.queryItems != nil && components.queryItems!.count >= 1 {
                    let queryItemCode = components.queryItems![0]
                    if queryItemCode.name == SharingInvitation.queryItemAuthorizationCode && queryItemCode.value != nil  {
                        Log.msg("queryItemCode.value: \(queryItemCode.value!)")
                        let code = queryItemCode.value!

                        ServerAPI.session.getSharingInvitationInfo(sharingInvitationUUID: code) { result in
                            switch result {
                            case .error(let error):
                                Log.error("\(error)")
                                Alert.show(withTitle: "Alert!", message: "There was an error contacting the server for the sharing information.")
                            case .success(let info):
                                switch info {
                                case .noInvitationFound:
                                    Alert.show(withTitle: "Alert!", message: "No invitation was found on the server. Did the invitation expire?")
                                case .invitation(let invite):
                                    if self.delegate == nil {
                                        self.invitation = invite
                                    }
                                    else {
                                        Thread.runSync(onMainThread: {
                                            self.delegate!.sharingInvitationReceived(invite)
                                        })
                                    }
                                }
                            }
                        }
                        
                        returnResult = true
                    }
                }
            }
        }

        return returnResult
    }
}
