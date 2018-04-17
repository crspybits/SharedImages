//
//  SyncServerDelegate.swift
//  SyncServer
//
//  Created by Christopher G Prince on 1/11/18.
//

import Foundation
import SMCoreLib

// Most of this information is for testing purposes and for UI (e.g., for displaying download progress). Some of it, however, can be necessary for app operations.
public enum SyncEvent {
    // This can repeat if there is a change to the files on the server (a master version update), and downloads restart.
    case willStartDownloads(numberContentDownloads:UInt, numberDownloadDeletions:UInt)
    
    case willStartUploads(numberContentUploads:UInt, numberUploadDeletions:UInt)
    
    // The attributes report the actual creation and update dates of the file-- as established by the server.
    case singleFileUploadComplete(attr:SyncAttributes)
    
    case singleAppMetaDataUploadComplete(fileUUID: String)

    case singleUploadDeletionComplete(fileUUID:UUIDString)
    case fileUploadsCompleted(numberOfFiles:Int)
    case uploadDeletionsCompleted(numberOfFiles:Int)
    
    case syncStarted
    
    // Occurs after call to stopSync, when the synchronization is just about to stop. syncDone will be the next event (if desired).
    case syncStopping
    
    case syncDone
    
    case refreshingCredentials
}

public struct EventDesired: OptionSet {
    public let rawValue: Int
    public init(rawValue:Int){ self.rawValue = rawValue}

    public static let willStartDownloads = EventDesired(rawValue: 1 << 0)
    public static let willStartUploads = EventDesired(rawValue: 1 << 1)

    public static let singleFileUploadComplete = EventDesired(rawValue: 1 << 2)
    public static let singleAppMetaDataUploadComplete = EventDesired(rawValue: 1 << 3)
    public static let singleUploadDeletionComplete = EventDesired(rawValue: 1 << 4)
    public static let fileUploadsCompleted = EventDesired(rawValue: 1 << 5)
    public static let uploadDeletionsCompleted = EventDesired(rawValue: 1 << 6)
    
    public static let syncStarted = EventDesired(rawValue: 1 << 7)
    public static let syncDone = EventDesired(rawValue: 1 << 8)
    
    public static let syncStopping = EventDesired(rawValue: 1 << 9)

    public static let refreshingCredentials = EventDesired(rawValue: 1 << 10)

    public static let defaults:EventDesired =
        [.singleFileUploadComplete, .singleUploadDeletionComplete, .fileUploadsCompleted,
         .uploadDeletionsCompleted]
    public static let all:EventDesired = EventDesired.defaults.union([EventDesired.syncStarted, EventDesired.syncDone, EventDesired.syncStopping, EventDesired.refreshingCredentials, EventDesired.willStartDownloads, EventDesired.willStartUploads, EventDesired.singleAppMetaDataUploadComplete])
    
    static func reportEvent(_ event:SyncEvent, mask:EventDesired, delegate:SyncServerDelegate?) {
    
        var eventIsDesired:EventDesired
        
        switch event {
        case .willStartDownloads:
            eventIsDesired = .willStartDownloads
            
        case .willStartUploads:
            eventIsDesired = .willStartUploads
            
        case .fileUploadsCompleted:
            eventIsDesired = .fileUploadsCompleted
            
        case .uploadDeletionsCompleted:
            eventIsDesired = .uploadDeletionsCompleted
        
        case .syncStarted:
            eventIsDesired = .syncStarted
            
        case .syncDone:
            eventIsDesired = .syncDone
            
        case .syncStopping:
            eventIsDesired = .syncStopping
            
        case .singleFileUploadComplete:
            eventIsDesired = .singleFileUploadComplete
            
        case .singleAppMetaDataUploadComplete:
            eventIsDesired = .singleAppMetaDataUploadComplete
            
        case .singleUploadDeletionComplete:
            eventIsDesired = .singleUploadDeletionComplete
        
        case .refreshingCredentials:
            eventIsDesired = .refreshingCredentials
        }
        
        if mask.contains(eventIsDesired) {
            Thread.runSync(onMainThread: {
                delegate?.syncServerEventOccurred(event: event)
            })
        }
    }
}

public struct ServerVersion {
    public let rawValue: String
    let major:Int
    let minor:Int
    let patch:Int
    
    // Format: X.Y.Z, where X, Y, and Z are integers.
    public init?(rawValue: String) {
        self.rawValue = rawValue
        
        let components = rawValue.components(separatedBy: ".")
        guard components.count == 3 else {
            return nil
        }
        
        guard let c1 = Int(components[0]),
            let c2 = Int(components[1]),
            let c3 = Int(components[2]) else {
            return nil
        }
        
        major = c1
        minor = c2
        patch = c3
    }

    // e.g., ServerVersion(rawValue: "1.2.3") < ServerVersion(rawValue: "2.0.0")
    public static func <(lhs: ServerVersion, rhs: ServerVersion) -> Bool {
        if lhs.major < rhs.major {
            return true
        }
        else if lhs.major == rhs.major && lhs.minor < rhs.minor {
            return true
        } else if lhs.major == rhs.major && lhs.minor == rhs.minor && lhs.patch < rhs.patch {
            return true
        }
        
        return false
    }
}

// Except as noted, these delegate methods are called on the main thread.

public protocol SyncServerDelegate : class {
    // The client has to decide how to resolve the content-download conflicts. The resolveConflict method of the SyncServerConflict must be called. The statements below apply for the SMRelativeLocalURL's.
    // Not called on the main thread. You must call the conflict resolution callbacks on the same thread as this was called on.
    // The `syncServerSingleFileDownloadComplete` will be called after, if you allow the download to continue. i.e., if you use acceptContentDownload of ContentDownloadResolution.
    // downloadedFile is nil only when this is an appMetaData download conflict.
    func syncServerMustResolveContentDownloadConflict(downloadedFile: SMRelativeLocalURL?, downloadedContentAttributes: SyncAttributes, uploadConflict: SyncServerConflict<ContentDownloadResolution>)
    
    /* Called at the end of a single download, on non-error conditions.
    The client owns the file referenced by the url after this call completes. This file is temporary in the sense that it will not be backed up to iCloud, could be removed when the device or app is restarted, and should be copied and/or moved to a more permanent location.
    Client should replace their existing data with that from the given file.
    This method doesn't get called for a particular download if (a) there is a conflict and (b) the client resolves that conflict by using .rejectFileDownload
    */
    func syncServerSingleFileDownloadComplete(url:SMRelativeLocalURL, attr: SyncAttributes)
    
    // If the app meta data on the server was updated without a corresponding file content change.
    func syncServerAppMetaDataDownloadComplete(attr: SyncAttributes)

    // The client has to decide how to resolve the download-deletion conflicts. The resolveConflict method of each SyncServerConflict must be called.
    // Conflicts will not include UploadDeletion.
    // Not called on the main thread. You must call the conflict resolution callbacks on the same thread as this was called on.
    typealias DownloadDeletionConflict = (downloadDeletion: SyncAttributes, uploadConflict: SyncServerConflict<DownloadDeletionResolution>)
    
    // The number of elements in this array reflects the number of conflicts in the download deletions. E.g., if there is only a single download deletion, there can be at most one conflict.
    // `syncServerShouldDoDeletions` will be called after this if you allow the deletion(s) to continue.
    func syncServerMustResolveDownloadDeletionConflicts(conflicts:[DownloadDeletionConflict])
    
    // Called when deletions have been received from the server. I.e., these files have been deleted on the server. This is received/called in an atomic manner: This reflects a snapshot state of file deletions on the server. Clients should delete the files referenced by the SyncAttributes's (i.e., the UUID's).
    // This may be called sometime after the deletions have been received from the server. E.g., on a recovery step after the app launches and not after recent server interaction.
    func syncServerShouldDoDeletions(downloadDeletions:[SyncAttributes])
    
    func syncServerErrorOccurred(error:SyncServerError)

    // Reports events. Useful for testing and UI.
    func syncServerEventOccurred(event:SyncEvent)
}

#if DEBUG
public protocol SyncServerTestingDelegate : class {
    // You *must* call `next` before returning.
    func syncServerSingleFileUploadCompleted(next: @escaping ()->())
    
     // You *must* call `next` before returning. If this delegate is given in testing, then `SyncServerDelegate` is not used for the corresponding method (without `next`).
     func singleFileDownloadComplete(url:SMRelativeLocalURL, attr: SyncAttributes, next: @escaping ()->())
}
#endif

