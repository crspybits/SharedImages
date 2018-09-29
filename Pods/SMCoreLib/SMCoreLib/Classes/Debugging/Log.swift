//
//  Log.swift
//  WhatDidILike
//
//  Created by Christopher Prince on 10/5/14.
//  Copyright (c) 2014 Spastic Muffin, LLC. All rights reserved.
//

import Foundation
import SwiftyBeaver

// See http://stackoverflow.com/questions/24114288/macros-in-swift
// And http://stackoverflow.com/questions/24048430/logging-method-signature-using-swift/31737561#31737561

open class Log {
    public static let logFileName = "logfile.txt"
    public static let logFileURL = FileStorage.url(ofItem: Log.logFileName)

    private let log = SwiftyBeaver.self
    fileprivate static let session = Log()
    fileprivate static let file = FileDestination()
    
    // Setting this to nil results in no logging output.
    public static var minLevel:SwiftyBeaver.Level? = nil {
        didSet {
            if minLevel == nil {
                Log.session.log.removeAllDestinations()
            }
            else {
                Log.session.log.removeAllDestinations()
                
                let console = ConsoleDestination()  // log to Xcode Console
                console.minLevel = minLevel!
                Log.session.log.addDestination(console)

                file.minLevel = minLevel!
                Log.session.log.addDestination(file)
            }
        }
    }

    // In the default arguments to these functions:
    // 1) If I use a String type, the macros (e.g., __LINE__) don't expand at run time.
    //  "\(__FUNCTION__)\(__FILE__)\(__LINE__)"
    // 2) A tuple type, like,
    // typealias SMLogFuncDetails = (String, String, Int)
    //  SMLogFuncDetails = (__FUNCTION__, __FILE__, __LINE__)
    //  doesn't work either.
    // 3) This String = __FUNCTION__ + __FILE__
    //  also doesn't work.
    
    fileprivate init() {
        Log.file.logFileURL = Log.logFileURL
        
        // Probably slows things down a bit, but we should be certain that each log write makes it to the file before returning.
        Log.file.syncAfterEachWrite = true
    }
    
    open class func redirectConsoleLogToDocumentFolder(clearRedirectLog:Bool) {
        LogFile.redirectConsoleLog(toDocumentFolder: clearRedirectLog)
    }
    
    // That above redirect redirects the stderr, which is not what Swift uses by default:
    // http://ericasadun.com/2015/05/22/swift-logging/
    // http://stackoverflow.com/questions/24041554/how-can-i-output-to-stderr-with-swift
    
    fileprivate class func logIt(_ string:String) {
        if !UIDevice.beingDebugged() {
            // When not attached to the debugger, this assumes we've redirected stderr to a file.
            fputs(string, stderr)
        }
    }

    open class func msg(_ message: String,
        functionName:  String = #function, fileNameWithPath: String = #file, lineNumber: Int = #line ) {

        let output = self.formatLogString(message, functionName: functionName, fileNameWithPath: fileNameWithPath, lineNumber: lineNumber)
        logIt(output)
        self.session.log.verbose(output)
    }
    
    // For use in debugging only. Doesn't log to file. Marks output in red.
    open class func error(_ message: String,
        functionName:  String = #function, fileNameWithPath: String = #file, lineNumber: Int = #line ) {
        
        let output = self.formatLogString(message, functionName: functionName, fileNameWithPath: fileNameWithPath, lineNumber: lineNumber)
        logIt(output)
        self.session.log.error(output)
    }
    
    // For use in debugging only. Doesn't log to file. Marks output in pink. (Yellow on white background is unreadable)
    open class func warning(_ message: String,
        functionName:  String = #function, fileNameWithPath: String = #file, lineNumber: Int = #line ) {
        let output = self.formatLogString(message, functionName: functionName, fileNameWithPath: fileNameWithPath, lineNumber: lineNumber)
        logIt(output)
        self.session.log.warning(output)
    }
    
    // For use in debugging only. Doesn't log to file. Marks output in purple.
    open class func special(_ message: String,
        functionName:  String = #function, fileNameWithPath: String = #file, lineNumber: Int = #line ) {
        let output = self.formatLogString(message, functionName: functionName, fileNameWithPath: fileNameWithPath, lineNumber: lineNumber)
        logIt(output)
        self.session.log.info(output)
    }

    /*
    fileprivate enum SMLoggingColor {
        case red
        case yellow // Can't read this on a white background
        case blue
        case purple
        case pink
        case none
    }
    */
    
    fileprivate class func formatLogString(_ message: String,
        functionName:  String, fileNameWithPath: String, lineNumber: Int) -> String {

        let fileNameWithoutPath = (fileNameWithPath as NSString).lastPathComponent
        
        let output = "\(Date()): \(message) [\(functionName) in \(fileNameWithoutPath), line \(lineNumber)]"

        return output
    }
    
    // Call this log method when something bad or important has happened.
    open class func file(_ message: String,
        functionName:  String = #function, fileNameWithPath: String = #file, lineNumber: Int = #line ) {
        
        var output:String
        
        // Log this in red because we typically log to a file because something important or bad has happened.
        output = self.formatLogString(message, functionName: functionName, fileNameWithPath: fileNameWithPath, lineNumber: lineNumber)
        logIt(output)
        self.session.log.error(output)
        
        output = self.formatLogString(message, functionName: functionName, fileNameWithPath: fileNameWithPath, lineNumber: lineNumber)
        LogFile.write(output + "\n")
    }
    
    open class func deleteLogFile() -> Bool {
        return Log.file.deleteLogFile()
    }
}

// From https://github.com/robbiehanson/XcodeColors
// Use this with XcodeColors plugin.
// Now defunct due to Xcode 8's lack of plugin support.

/*
struct SMColorLog {
    static let ESCAPE = "\u{001b}["
    
    static let RESET_FG = ESCAPE + "fg;" // Clear any foreground color
    static let RESET_BG = ESCAPE + "bg;" // Clear any background color
    static let RESET = ESCAPE + ";"   // Clear any foreground or background color
    
    static func red<T>(_ object:T) -> String {
        return "\(ESCAPE)fg255,0,0;\(object)\(RESET)"
    }
    
    static func green<T>(_ object:T) -> String {
        return("\(ESCAPE)fg0,255,0;\(object)\(RESET)")
    }
    
    static func blue<T>(_ object:T) -> String {
        return "\(ESCAPE)fg0,0,255;\(object)\(RESET)"
    }
    
    static func yellow<T>(_ object:T) -> String {
        return "\(ESCAPE)fg255,255,0;\(object)\(RESET)"
    }
    
    static func purple<T>(_ object:T) -> String {
        return "\(ESCAPE)fg255,0,255;\(object)\(RESET)"
    }
    
    static func pink<T>(_ object:T) -> String {
        return "\(ESCAPE)fg255,105,180;\(object)\(RESET)"
    }
    
    static func cyan<T>(_ object:T) -> String {
        return "\(ESCAPE)fg0,255,255;\(object)\(RESET)"
    }
}
*/
