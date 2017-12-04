//
//  Types.swift
//  Server
//
//  Created by Christopher Prince on 1/25/17.
//
//

import Foundation

public typealias MasterVersionInt = Int64
public typealias FileVersionInt = Int32
public typealias UserId = Int64
public typealias SharingInvitationId = Int64

public enum ServerHTTPMethod : String {
    case get
    case post
    case delete
}

public enum HTTPStatus : Int {
    case ok = 200
    case unauthorized = 401
}

public enum AuthenticationLevel {
    case none
    case primary // e.g., Google or Facebook credentials required
    case secondary // must also have a record of user in our database tables
}

public enum SharingPermission : String {
    case read // aka download
    case write // aka upload; includes read
    case admin // read, write, and invite

    public static func maxStringLength() -> Int {
        return max(SharingPermission.read.rawValue.characters.count, SharingPermission.write.rawValue.characters.count, SharingPermission.admin.rawValue.characters.count)
    }
    
    public func hasMinimumPermission(_ min:SharingPermission) -> Bool {
        switch self {
        case .read:
            // Users with read permission can do only read operations.
            return min == .read
            
        case .write:
            // Users with write permission can do .read and .write operations.
            return min == .read || min == .write
            
        case .admin:
            // admin permissions can do anything.
            return true
        }
    }
    
    public func userFriendlyText() -> String {
        switch self {
        case .read:
            return "Read-only"
        case .write:
            return "Read & Change"
        case .admin:
            return "Read, Change, & Invite"
        }
    }
}

public struct SignInType: OptionSet {
    public let rawValue: Int
    
    public init(rawValue: Int) { self.rawValue = rawValue }
    
    public static let owningUser = SignInType(rawValue: 1 << 0)
    public static let sharingUser = SignInType(rawValue: 1 << 1)
    public static let both:SignInType = [.owningUser, .sharingUser]
}

// Both SignInType and UserType because UserType disallows `both`.
public enum UserType : String {
    case sharing // user is sharing data
    case owning // user owns the data

    public static func maxStringLength() -> Int {
        return max(UserType.sharing.rawValue.characters.count, UserType.owning.rawValue.characters.count)
    }
}
