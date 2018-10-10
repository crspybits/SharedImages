//
//  LocalURLData.swift
//  SyncServer
//
//  Created by Christopher G Prince on 12/31/17.
//

import Foundation
import SMCoreLib

protocol LocalURLData : class {
    var localURLData:NSData? {get set}
}

extension LocalURLData {
    func getLocalURLData() -> SMRelativeLocalURL? {
        if localURLData == nil {
            return nil
        }
        else {
            let url = NSKeyedUnarchiver.unarchiveObject(with: localURLData! as Data) as? SMRelativeLocalURL
            Assert.If(url == nil, thenPrintThisString: "Yikes: No URL!")
            return url
        }
    }
    
    func setLocalURLData(newValue:SMRelativeLocalURL?) {
        if newValue == nil {
            localURLData = nil
        }
        else {
            localURLData = NSKeyedArchiver.archivedData(withRootObject: newValue!) as NSData
        }
    }
}
