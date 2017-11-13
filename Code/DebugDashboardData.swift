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
    
    func sections() -> [[RosterDevRowContents]] {
        return [debugDashboardEnvironments]
    }
}
