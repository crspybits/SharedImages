//
//  ResponseMessage.swift
//  Server
//
//  Created by Christopher Prince on 11/27/16.
//
//

import Foundation
import Gloss

public enum ResponseType {
case json
case data(data: Data?)
}

public protocol ResponseMessage : Gloss.Encodable, Gloss.Decodable {
    init?(json: JSON)
    var responseType:ResponseType {get}
}

