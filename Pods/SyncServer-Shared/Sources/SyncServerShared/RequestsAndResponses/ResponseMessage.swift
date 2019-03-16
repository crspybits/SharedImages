//
//  ResponseMessage.swift
//  Server
//
//  Created by Christopher Prince on 11/27/16.
//
//

import Foundation

public enum ResponseType {
    case json
    case data(data: Data?)

    // The response fields are the value of an HTTP header key.
    case header
}

public protocol ResponseMessage : Codable {
    init()
    var responseType:ResponseType {get}
    var toDictionary: [String: Any]? {get}
}

public extension ResponseMessage {
    public var toDictionary: [String: Any]? {
        return MessageEncoder.toDictionary(encodable: self)
    }
}

