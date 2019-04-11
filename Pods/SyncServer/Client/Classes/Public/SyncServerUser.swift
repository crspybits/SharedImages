//
//  SyncServerUser.swift
//  SyncServer
//
//  Created by Christopher Prince on 12/2/16.
//  Copyright © 2016 Spastic Muffin, LLC. All rights reserved.
//

import Foundation
import SMCoreLib
import SyncServer_Shared
import PersistentValue

public class SyncServerUser {
    var desiredEvents:EventDesired!
    weak var delegate:SyncServerDelegate!

    public var creds:GenericCredentials? {
        didSet {
            ServerAPI.session.creds = creds
        }
    }
    
    // Persisting this in the keychain for security-- I'd rather this identifier wasn't known to more folks than need it.
    static let syncServerUserId = try! PersistentValue<String>(name: "SyncServerUser.syncServerUserId2", storage: .keyChain)
    
    /// A unique identifier for the user on the SyncServer system. If creds are set this will be set.
    public var syncServerUserId:String? {
        if SyncServerUser.syncServerUserId.value == "" {
            return nil
        }
        else {
            return SyncServerUser.syncServerUserId.value
        }
    }
    
    // Keeping these comments so I know the user keys used for them.
    // static let sharingGroupIds = SMPersistItemData(name: "SyncServerUser.sharingGroupIds", initialDataValue: Data(), persistType: .userDefaults)
    // static let sharingGroups = SMPersistItemData(name: "SyncServerUser.sharingGroups", initialDataValue: Data(), persistType: .userDefaults)
    
    public private(set) var cloudFolderName:String?
    
    public static let session = SyncServerUser()
    
    func appLaunchSetup(cloudFolderName:String?) {
        self.cloudFolderName = cloudFolderName
    }

    // A distinct UUID for this user mobile device.
    // I'm going to persist this in the keychain not so much because it needs to be secure, but rather because it will survive app deletions/reinstallations.
    static let mobileDeviceUUID = try! PersistentValue<String>(name: "SyncServerUser.mobileDeviceUUID2", storage: .keyChain)
    
    private init() {
        // Check to see if the device has a UUID already.
        if SyncServerUser.mobileDeviceUUID.value == nil {
            SyncServerUser.mobileDeviceUUID.value = UUID.make()
        }
        
        ServerAPI.session.delegate = self
    }
    
    public enum CheckForExistingUserResult {
        case noUser
        case user(accessToken:String?)
    }
    
    fileprivate func showAlert(with title:String, and message:String? = nil) {
        let window = UIApplication.shared.keyWindow
        let rootViewController = window?.rootViewController
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.popoverPresentationController?.sourceView = rootViewController?.view
        alert.addAction(UIAlertAction(title: "OK", style: .cancel, handler: nil))
        
        Thread.runSync(onMainThread: {
            rootViewController?.present(alert, animated: true, completion: nil)
        })
    }
    
    /// Calls the server API method to check credentials.
    public func checkForExistingUser(creds: GenericCredentials,
        completion:@escaping (_ result: CheckForExistingUserResult?, Error?) ->()) {
        
        // Have to do this before call to `checkCreds` because it sets up creds with the ServerAPI.
        ServerAPI.session.creds = creds
        Log.msg("SignInCreds: \(creds)")
        
        ServerAPI.session.checkCreds {[unowned self] (checkCredsResult, error) in
            var checkForUserResult:CheckForExistingUserResult?
            let errorResult = error
            
            switch checkCredsResult {
            case .none:
                ServerAPI.session.creds = nil
                // Don't sign the user out here. Callers of `checkForExistingUser` (e.g., GoogleSignIn or FacebookSignIn) can deal with this.
                Log.error("Had an error: \(String(describing: error))")
                
            case .some(.noUser):
                ServerAPI.session.creds = nil
                // Definitive result from server-- there was no user. Still, I'm not going to sign the user out here. Callers can do that.
                checkForUserResult = .noUser
            
            case .some(.user(let syncServerUserId, let accessToken)):
                self.creds = creds
                checkForUserResult = .user(accessToken:accessToken)
                SyncServerUser.syncServerUserId.value = "\(syncServerUserId)"
                
                Download.session.onlyUpdateSharingGroups() { error in
                    if error != nil {
                        Thread.runSync(onMainThread: {
                            self.showAlert(with: "Error trying to sign in: \(error!)")
                        })
                    }
                    Thread.runSync(onMainThread: {
                        completion(checkForUserResult, error)
                    })
                }
                return
            }
            
            if case .some(.noUser) = checkForUserResult {
                Thread.runSync(onMainThread: {
                    self.showAlert(with: "\(creds.uiDisplayName) doesn't exist on the system.", and: "You can sign in as a \"New user\", or get a sharing invitation from another user.")
                })
            }
            else if errorResult != nil {
                Thread.runSync(onMainThread: {
                    self.showAlert(with: "Error trying to sign in: \(errorResult!)")
                })
            }
            
            Thread.runSync(onMainThread: {
                completion(checkForUserResult, errorResult)
            })
        }
    }
    
    /// Calls the server API method to add a user.
    public func addUser(creds: GenericCredentials, sharingGroupUUID: String, sharingGroupName: String?, completion:@escaping (Error?) ->()) {
        Log.msg("SignInCreds: \(creds)")
        
        var alreadyExists = false
        CoreDataSync.perform(sessionName: Constants.coreDataName) {
            if let _ = SharingEntry.fetchObjectWithUUID(uuid: sharingGroupUUID) {
                alreadyExists = true
            }
        }
        
        if alreadyExists {
            Thread.runSync(onMainThread: {
                completion(SyncServerError.generic("Sharing Group UUID already exists!"))
            })
        }
        
        ServerAPI.session.creds = creds
        ServerAPI.session.addUser(cloudFolderName: cloudFolderName, sharingGroupUUID: sharingGroupUUID, sharingGroupName: sharingGroupName) { syncServerUserId, error in
            if error == nil {
                var saveError: Error?
                CoreDataSync.perform(sessionName: Constants.coreDataName) {
                    let sharingEntry = SharingEntry.newObject() as! SharingEntry
                    sharingEntry.sharingGroupUUID = sharingGroupUUID
                    sharingEntry.sharingGroupName = sharingGroupName
                    sharingEntry.permission = .admin
                    
                    do {
                        try CoreData.sessionNamed(Constants.coreDataName).context.save()
                    } catch (let error) {
                        saveError = error
                    }
                }
                
                if saveError != nil {
                    Thread.runSync(onMainThread: {
                        completion(SyncServerError.otherError(saveError!))
                    })
                    return
                }
                
                self.creds = creds
                if let syncServerUserId = syncServerUserId  {
                    SyncServerUser.syncServerUserId.value = "\(syncServerUserId)"
                }
            }
            else {
                Log.error("Error: \(String(describing: error))")
                ServerAPI.session.creds = nil
                Thread.runSync(onMainThread: {
                    self.showAlert(with: "Failed adding user \(creds.uiDisplayName).", and: "Error was: \(error!).")
                })
            }
            
            Thread.runSync(onMainThread: {
                completion(error)
            })
        }
    }
    
    /// Calls the server API method to create a sharing invitation.
    public func createSharingInvitation(withPermission permission:Permission, sharingGroupUUID: String, numberAcceptors: UInt, allowSharingAcceptance: Bool = true, completion:((_ invitationCode:String?, Error?)->(Void))?) {

        ServerAPI.session.createSharingInvitation(withPermission: permission, sharingGroupUUID: sharingGroupUUID, numberAcceptors: numberAcceptors, allowSharingAcceptance: allowSharingAcceptance) { (sharingInvitationUUID, error) in
            Thread.runSync(onMainThread: {
                completion?(sharingInvitationUUID, error)
            })
        }
    }
    
    /// Calls the server API method to get sharing invitation info.
    public func getSharingInvitationInfo(invitationCode:String, completion:((_ info:SyncServer.SharingInvitationInfo?, Error?)->(Void))?) {
        
        ServerAPI.session.getSharingInvitationInfo(sharingInvitationUUID: invitationCode) { response in
            switch response {
            case .error(let error):
                Thread.runSync(onMainThread: {
                    completion?(nil, error)
                })
            case .success(let info):
                Thread.runSync(onMainThread: {
                    completion?(info, nil)
                })
            }
        }
    }
    
    /// Calls the server API method to redeem a sharing invitation.
    public func redeemSharingInvitation(creds: GenericCredentials, invitationCode:String, cloudFolderName: String?, completion:((_ accessToken:String?, _ sharingGroupUUID: String?, Error?)->())?) {
        
        ServerAPI.session.creds = creds
        
        ServerAPI.session.redeemSharingInvitation(sharingInvitationUUID: invitationCode, cloudFolderName: cloudFolderName) { accessToken, sharingGroupUUID, error in
            if error == nil {
                self.creds = creds
            }
            else {
                // 12/14/18; This was probably appropriate previously when users could just be a member of a single "sharing group", but now when they can be in multiple, it's not. See https://github.com/crspybits/SharedImages/issues/152
                // ServerAPI.session.creds = nil
                
                // What I really need here is a definitive answer to "Is this user on the system?". A simple answer seems to be just checking self.creds. This will mean they've already been signed in-- and hence we know they are in the system.
                if self.creds == nil || !equals(lhs: self.creds!, rhs: ServerAPI.session.creds!) {
                    self.creds = nil
                }
            }
            
            Thread.runSync(onMainThread: {
                completion?(accessToken, sharingGroupUUID, error)
            })
        }
    }
    
    /// Register the APNS token for the users device.
    public func registerPushNotificationToken(token: String, completion:((Error?)->())?) {
        ServerAPI.session.registerPushNotificationToken(token: token) { error in
            Thread.runSync(onMainThread: {
                completion?(error)
            })
        }
    }
}

extension SyncServerUser : ServerAPIDelegate {    
    func deviceUUID(forServerAPI: ServerAPI) -> Foundation.UUID {
        return Foundation.UUID(uuidString: SyncServerUser.mobileDeviceUUID.value!)!
    }

    func userWasUnauthorized(forServerAPI: ServerAPI) {
        Thread.runSync(onMainThread: {
            self.showAlert(with: "The server is having problems authenticating you. You may need to sign out and sign back in.")
        })
    }

#if DEBUG
    func doneUploadsRequestTestLockSync(forServerAPI: ServerAPI) -> TimeInterval? {
        return nil
    }
    
    func indexRequestServerSleep(forServerAPI: ServerAPI) -> TimeInterval? {
        return nil
    }
#endif
}


