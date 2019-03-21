//
//  XCGLogger+Extras.swift
//  SyncServer
//
//  Created by Christopher G Prince on 3/21/19.
//

import Foundation
import XCGLogger

extension XCGLogger {
    func msg(_ output: String) {
        Log.info(output)
    }
    
    func special(_ output: String) {
        Log.info(output)
    }
}
