//
//  Filenaming.swift
//  Server
//
//  Created by Christopher Prince on 1/20/17.
//
//

import Foundation

// In some situations on the client, I need this
#if !SERVER
public struct FilenamingObject : Filenaming {
    public let fileUUID:String!
    public let fileVersion:Int32!
    
    // The default member-wise initializer is not public. :(. See https://stackoverflow.com/questions/26224693/how-can-i-make-public-by-default-the-member-wise-initialiser-for-structs-in-swif
    public init(fileUUID:String, fileVersion:Int32) {
        self.fileUUID = fileUUID
        self.fileVersion = fileVersion
    }
}
#endif

public protocol Filenaming {
    var fileUUID:String! {get}
    var fileVersion:Int32! {get}

#if SERVER
    func cloudFileName(deviceUUID:String) -> String
#endif
}

#if SERVER
public extension Filenaming {
    
    /* We are not going to use just the file UUID to name the file in the cloud service. This is because we are not going to hold a lock across multiple file uploads, and we need to make sure that we don't have a conflict when two or more devices attempt to concurrently upload the same file. The file name structure we're going to use is given by this method.
    */
    public func cloudFileName(deviceUUID:String) -> String {
        return "\(fileUUID!).\(deviceUUID).\(fileVersion!)"
    }
}
#endif
