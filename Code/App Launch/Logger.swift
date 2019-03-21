//
//  Logger.swift
//  SharedImages
//
//  Created by Christopher G Prince on 3/17/19.
//  Copyright © 2019 Spastic Muffin, LLC. All rights reserved.
//

import Foundation
import XCGLogger

class Logger {
    private static var session = Logger()
    private var fileDestination:AutoRotatingFileDestination!
    
    private static var logFileURL: URL {
        let urls = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        let result = URL(fileURLWithPath: urls[0].path + "/" + "Logfile")
        return result
    }
    
    static var archivedFileURLs: [URL] {
        return session.fileDestination.archivedFileURLs() + [logFileURL]
    }
    
    static func setup() -> XCGLogger {
        var level:XCGLogger.Level
#if DEBUG
        level = .verbose
#else
        level = .error
#endif
        
        // Create a logger object with no destinations
        let log = XCGLogger(identifier: "advancedLogger", includeDefaultDestinations: false)
        
        // Create a destination for the system console log (via NSLog)
        let systemDestination = AppleSystemLogDestination(identifier: "advancedLogger.systemDestination")

        // Optionally set some configuration options
        systemDestination.outputLevel = level
        systemDestination.showLogIdentifier = false
        systemDestination.showFunctionName = true
        systemDestination.showThreadName = true
        systemDestination.showLevel = true
        systemDestination.showFileName = true
        systemDestination.showLineNumber = true
        systemDestination.showDate = true

        // Add the destination to the logger
        log.add(destination: systemDestination)
        
        // Create a file log destination
        session.fileDestination = AutoRotatingFileDestination(writeToFile: logFileURL.path, identifier: "advancedLogger.fileDestination", shouldAppend: true)
        
        // Optionally set some configuration options
        session.fileDestination.outputLevel = level
        session.fileDestination.showLogIdentifier = false
        session.fileDestination.showFunctionName = true
        session.fileDestination.showThreadName = true
        session.fileDestination.showLevel = true
        session.fileDestination.showFileName = true
        session.fileDestination.showLineNumber = true
        session.fileDestination.showDate = true
        
        // Trying to get max total log size that could be sent to developer to be around 1MByte; this comprises one current log file and two archived log files.
        session.fileDestination.targetMaxFileSize = (1024 * 1024) / 3 // 1/3 MByte
        
        // These are archived log files.
        session.fileDestination.targetMaxLogFiles = 2

        // Process this destination in the background
        session.fileDestination.logQueue = XCGLogger.logQueue

        // Add the destination to the logger
        log.add(destination: session.fileDestination)

        // Add basic app info, version info etc, to the start of the logs
        log.logAppDetails()

        return log
    }
}
