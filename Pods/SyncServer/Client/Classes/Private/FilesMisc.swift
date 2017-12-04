//
//  FilesMisc.swift
//  SyncServer
//
//  Created by Christopher Prince on 1/30/16.
//  Copyright © 2016 Spastic Muffin, LLC. All rights reserved.
//

// Misc internal file operations.

import Foundation
import SMCoreLib

public class FilesMisc {

    // Creates a file within the Documents/<SMAppConstants.tempDirectory> directory. If the URL returned is non-nil, the file will have been created, and zero length upon return.
    public class func createTemporaryRelativeFile() -> SMRelativeLocalURL? {
        
        // I'm going to use a directory within /Documents and not the NSTemporaryDirectory because I want control over when these files are deleted. E.g., It is possible that it will take any number of days for these files to be uploaded. I don't want to take the chance that they will be deleted before I'm done with them.
        
        guard let tempDirectory = FileStorage.path(toItem: Constants.tempDirectory) else {
            Log.error("nil result from FileStorage.path")
            return nil
        }
        
        let tempDirURL = URL(fileURLWithPath: tempDirectory)
        
        // Don't let these temporary files be backed up to iCloud-- Apple doesn't like this (e.g., when reviewing apps).
        if FileStorage.createDirectoryIfNeeded(tempDirURL) {
            let result = FileStorage.addSkipBackupAttributeToItem(at: tempDirURL)
            Assert.If(!result, thenPrintThisString: "Could not addSkipBackupAttributeToItemAtURL")
        }
        
        guard let tempFileName = FileStorage.createTempFileName(inDirectory: tempDirectory, withPrefix: "SyncServer", andExtension: "dat") else {
            Log.error("Could not createTempFileName")
            return nil
        }
        
        let fileNameWithPath = tempDirectory + "/" + tempFileName
        Log.msg(fileNameWithPath);
        
        let relativeLocalFile = SMRelativeLocalURL(withRelativePath: Constants.tempDirectory + "/" + tempFileName, toBaseURLType: .documentsDirectory)

        if FileManager.default.createFile(atPath: relativeLocalFile!.path!, contents: nil, attributes: nil) {
            return relativeLocalFile
        }
        else {
            Log.error("Could not create file: \(fileNameWithPath)")
            return nil
        }
    }
    
#if DEBUG
    // Returns true iff the files are bytewise identical.
    public class func compareFiles(file1:URL, file2:URL) -> Bool {
        // Not the best (consumes lots of RAM), but good enough for now.
        do {
            let file1Data = try Data(contentsOf: file1)
            let file2Data = try Data(contentsOf: file2)
            return file1Data == file2Data
        } catch (let error) {
            Log.error("Error when reading data from file(s): \(error)")
            return false
        }
    }
    
    // Returns true iff the files are bytewise identical.
    public class func compareFile(file:URL, andString string:String) -> Bool {
        // Not the best (consumes lots of RAM), but good enough for now.
        do {
            let fileData = try Data(contentsOf: file)
            let stringData = string.data(using: String.Encoding.utf8)
        return fileData == stringData
        } catch (let error) {
            Log.error("Error when reading data from file: \(error)")
            return false
        }
    }
#endif
}
