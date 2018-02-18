//
//  Types.swift
//  SharedImages
//
//  Created by Christopher G Prince on 2/16.18.
//  Copyright © 2018 Spastic Muffin, LLC. All rights reserved.
//

import Foundation

func typeName(_ some: Any) -> String {
    return (some is Any.Type) ? "\(some)" : "\(type(of: some))"
}
