//
//  SyncServerConflict.swift
//  SyncServer
//
//  Created by Christopher G Prince on 1/11/18.
//

import Foundation

public enum DownloadDeletionResolution {
    // Download deletions can only conflict with file uploads. A server download deletion and a client file upload deletion don't conflict (it's just two people trying to delete at about the same time, which is fine).
    
    public enum FileUploadResolution {
        case keepFileUpload
        case removeFileUpload
    }
    
    // Deletes the existing file upload.
    case acceptDownloadDeletion
    
    case rejectDownloadDeletion(FileUploadResolution)
}

public enum FileDownloadResolution {
    // File downloads can conflict with file upload(s) and/or an upload deletion. See the conflictType of the specific `SyncServerConflict`.
    
    // This is used in `rejectFileDownload` below.
    public struct UploadResolution : OptionSet {
        public let rawValue: Int
        public init(rawValue:Int){ self.rawValue = rawValue}
        
        // If you are going to use `rejectFileDownload` (see below), this the typical upload resolution.
        public static let keepAll:UploadResolution = [keepFileUploads, keepUploadDeletions]
        
        // Remove any conflicting local file uploads and/or upload deletions.
        public static let removeAll = UploadResolution(rawValue: 0)
        
        // Not having this option means to remove your conflicting file uploads
        public static let keepFileUploads = UploadResolution(rawValue: 1 << 0)
        
        public var keepFileUploads:Bool {
            return self.contains(UploadResolution.keepFileUploads)
        }
        
        public var removeFileUploads:Bool {
            return !self.contains(UploadResolution.keepFileUploads)
        }
        
        // Not having this option means to remove your conflicting upload deletions.
        public static let keepUploadDeletions = UploadResolution(rawValue: 1 << 1)
        
        public var keepUploadDeletions:Bool {
            return self.contains(UploadResolution.keepUploadDeletions)
        }
        
        public var removeUploadDeletions:Bool {
            return !self.contains(UploadResolution.keepUploadDeletions)
        }
    }
    
    // Deletes any conflicting file upload and/or upload deletion.
    case acceptFileDownload
    
    case rejectFileDownload(UploadResolution)
}

// When you receive a conflict in a callback method, you must resolve the conflict by calling resolveConflict.
public class SyncServerConflict<R> {
    typealias callbackType = ((R)->())!
    
    var conflictResolved:Bool = false
    var resolutionCallback:((R)->())!
    
    init(conflictType: ClientOperation, resolutionCallback:callbackType) {
        self.conflictType = conflictType
        self.resolutionCallback = resolutionCallback
    }
    
    // Because downloads are higher-priority (than uploads) with the SyncServer, all conflicts effectively originate from a server download operation: A download-deletion or a file-download. The type of server operation will be apparent from the context.
    // And the conflict is between the server operation and a local, client operation:
    public enum ClientOperation : String {
        case uploadDeletion
        case fileUpload
        case bothFileUploadAndDeletion
    }
    
    public private(set) var conflictType:ClientOperation!
    
    public func resolveConflict(resolution:R) {
        assert(!conflictResolved, "Already resolved!")
        conflictResolved = true
        resolutionCallback(resolution)
    }
}

