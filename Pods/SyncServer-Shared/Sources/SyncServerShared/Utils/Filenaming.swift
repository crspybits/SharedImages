//
//  Filenaming.swift
//  Server
//
//  Created by Christopher Prince on 1/20/17.
//
//

import Foundation

public enum MimeType: String {
    case text = "text/plain"
    case jpeg = "image/jpeg"
    
    // A file with a .url extension with the format https://fileinfo.com/extension/url
    // A more standard url mime type is https://tools.ietf.org/html/rfc2483#section-5 but I want to use a file format that can easily be launched in Windows and Mac OS.
    case url = "application/x-url"
    
    // This is really an error state. Use it with care.
    case unknown = "unknown"
}

public struct Extension {
    public static func forMimeType(mimeType:String) -> String {
        let defaultExt = "dat"
        guard let mimeTypeEnum = MimeType(rawValue: mimeType) else {
            return defaultExt
        }
        
        switch mimeTypeEnum {
        case .text:
            return "txt"
        case .jpeg:
            return "jpg"
        case .url:
            return "url"
            
        case .unknown:
            return "unknown"
        }
    }
}

// In some situations on the client, I need this
#if !SERVER
public struct FilenamingWithAppMetaDataVersion : Filenaming {
    public let fileUUID:String!
    public let fileVersion:Int32!
    public var appMetaDataVersion:AppMetaDataVersionInt?

    // The default member-wise initializer is not public. :(. See https://stackoverflow.com/questions/26224693/how-can-i-make-public-by-default-the-member-wise-initialiser-for-structs-in-swif
    public init(fileUUID:String, fileVersion:Int32, appMetaDataVersion:AppMetaDataVersionInt?) {
        self.fileUUID = fileUUID
        self.fileVersion = fileVersion
        self.appMetaDataVersion = appMetaDataVersion
    }
}
#endif

public protocol Filenaming {
    var fileUUID:String! {get}
    var fileVersion:FileVersionInt! {get}
    
#if SERVER
    func cloudFileName(deviceUUID:String, mimeType:String) -> String
#endif
}

#if SERVER
public extension Filenaming {
    /* We are not going to use just the file UUID to name the file in the cloud service. This is because we are not going to hold a lock across multiple file uploads, and we need to make sure that we don't have a conflict when two or more devices attempt to concurrently upload the same file. The file name structure we're going to use is given by this method.
    */
    public func cloudFileName(deviceUUID:String, mimeType:String) -> String {
        let ext = Extension.forMimeType(mimeType: mimeType)
        return "\(fileUUID!).\(deviceUUID).\(fileVersion!).\(ext)"
    }
}
#endif
