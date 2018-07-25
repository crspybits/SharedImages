//
//  GetSharingGroups.swift
//  SyncServer-Shared
//
//  Created by Christopher G Prince on 7/15/18.
//

import Foundation
import Gloss

#if SERVER
import Kitura
#endif

public class GetSharingGroupsRequest : NSObject, RequestMessage {
#if SERVER
    public required convenience init?(request: RouterRequest) {
        self.init(json: request.queryParameters)
    }
#endif
    
    public required init?(json: JSON) {
        super.init()
    }
    
    public func toJSON() -> JSON? {
        return jsonify([
        ])
    }
}

public class GetSharingGroupsResponse : ResponseMessage {
    // The sharing groups in which this user is a member.
    public static let sharingGroupIdsKey = "sharingGroupIds"
    public var sharingGroupIds:[SharingGroupId]!
    
    public var responseType: ResponseType {
        return .json
    }
    
    public required init?(json: JSON) {
        self.sharingGroupIds =  Decoder.decode(int64ArrayForKey:GetSharingGroupsResponse.sharingGroupIdsKey)(json)
    }
    
    public convenience init?() {
        self.init(json:[:])
    }
    
    // MARK: - Serialization
    public func toJSON() -> JSON? {
        return jsonify([
            GetSharingGroupsResponse.sharingGroupIdsKey ~~> self.sharingGroupIds
        ])
    }
}
