//
//  DebugDashboardData.swift
//  SharedImages
//
//  Created by Christopher G Prince on 11/12/17.
//  Copyright © 2017 Spastic Muffin, LLC. All rights reserved.
//

import Foundation
import rosterdev
import SMCoreLib
import SyncServer

class DebugDashboardData {
    private init() {
    }
    
    static let session = DebugDashboardData()
    
    var debugDashboardEnvironments: [RosterDevRowContents] = {
        func alert(usingParentVC parentVC: UIViewController) {
            SMCoreLib.Alert.show(fromVC: parentVC, withTitle: "This change gets used the next time the app starts")
        }
        
        var useDev = RosterDevRowContents(name: "Use staging environment", action: { parentVC in
            alert(usingParentVC: parentVC)
            Environment.current = .staging
        })
        useDev.checkMark = {
            return Environment.current == .staging
        }
        
        var useProd = RosterDevRowContents(name: "Use prod environment", action: { parentVC in
            alert(usingParentVC: parentVC)
            Environment.current = .production
        })
        useProd.checkMark = {
            return Environment.current == .production
        }
        
        return [useDev, useProd]
    }()
    
    var otherControls: [RosterDevRowContents] = {
        var resetTrackers = RosterDevRowContents(name: "Reset internal trackers", action: { parentVC in
            SMCoreLib.Alert.show(fromVC: parentVC, withTitle: "Really reset internal trackers?") {
                do {
                    try SyncServer.session.reset(type: .tracking)
                } catch (let error) {
                    SMCoreLib.Alert.show(fromVC: parentVC, withTitle: "Alert!", message: "Error resetting internal trackers: \(error)")
                }
            }
        })
        
        return [resetTrackers]
    }()
    
    func sections() -> [[RosterDevRowContents]] {
        return [debugDashboardEnvironments, otherControls]
    }
}
