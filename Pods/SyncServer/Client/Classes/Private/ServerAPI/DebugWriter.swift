//
//  DebugWriter.swift
//  Background
//
//  Created by Christopher G Prince on 1/4/18.
//  Copyright © 2018 Christopher G Prince. All rights reserved.
//

import Foundation
import SMCoreLib

class DebugWriter {
    private var file: FileHandle!
    static let session = DebugWriter()
    
    private init() {
        let dirs: [String] = NSSearchPathForDirectoriesInDomains(FileManager.SearchPathDirectory.documentDirectory, FileManager.SearchPathDomainMask.allDomainsMask, true)
        let filePath = dirs[0] + "/debugging.txt"
        
        // First create the file. FileHandle doesn't do that.
        FileManager.default.createFile(atPath: filePath, contents: nil, attributes: nil)

        file = FileHandle(forWritingAtPath: filePath)
        print("path: \(filePath)")
    }
    
    func log(_ s:String) {
        Log.msg(s)
        guard let file = file, let data = (s + "\n").data(using: String.Encoding.utf8) else {
            return
        }
        
        file.write(data)
        file.synchronizeFile()
    }
}
