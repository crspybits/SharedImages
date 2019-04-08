//
//  SMDefs.swift
//  Catsy
//
//  Created by Christopher Prince on 7/12/15.
//  Copyright (c) 2015 Spastic Muffin, LLC. All rights reserved.
//

import Foundation

// @objc so can access members from Objective-C
@objc open class SMDefs : NSObject {
    // MARK: SMUserFeedbackModel
    
    // Distinct dates on which app has been launched
    public static let ACTIVE_DATES =
        SMPersistItemSet(name: "SMActiveDates", initialSetValue:NSMutableSet(), persistType:.userDefaults)
    
    // Number of times app launched
    public static let NUMBER_ACTIVE = SMPersistItemInt(name: "SMNumberActive", initialIntValue:0, persistType:.userDefaults)
    
    // Number of times the user has been asked
    public static let NUMBER_ASKS = SMPersistItemInt(name: "SMNumberAsks", initialIntValue:0, persistType:.userDefaults)
    
    // Has the user responded?
    public static let USER_RESPONDED = SMPersistItemBool(name: "SMUserResponded", initialBoolValue:false, persistType:.userDefaults)
    
    // MARK: CoreData

    // Current version number of the core data model. Update this if up you update the core data model version and need to migrate.
    public static let CURR_CORE_DATA_MODEL_NUMBER = 1
    
    public static let CURR_CORE_DATA_MODEL = SMPersistItemInt(name: "SMCurrCoreDataModel", initialIntValue:CURR_CORE_DATA_MODEL_NUMBER, persistType:.userDefaults)
}
