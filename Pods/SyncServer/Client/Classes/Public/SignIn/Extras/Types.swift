//
//  Types.swift
//  SyncServer
//
//  Created by Christopher G Prince on 7/28/17.
//  Copyright © 2017 Spastic Muffin, LLC. All rights reserved.
//

import Foundation

func typeName(_ some: Any) -> String {
    return (some is Any.Type) ? "\(some)" : "\(type(of: some))"
}
