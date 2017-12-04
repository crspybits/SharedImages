//
//  FileStorage.h
//
//  Created by Christopher Prince on 9/28/14.
//  Copyright (c) 2014 Spastic Muffin, LLC. All rights reserved.
//

// Data which will persist even if the app is not running (stored in files).

#import <Foundation/Foundation.h>

@interface FileStorage : NSObject

// Returns the path name to a file or folder in the Documents directory.
// fileName given doesn't have path components. The directory or file doesn't have to exist.
+ (NSString *)pathToItem: (NSString *) fileOrFolderNameWithoutPath;
+ (NSURL *)urlOfItem: (NSString *) fileOrFolderNameWithoutPath;

// Check if an item (folder or file) in /Documents exists
+ (BOOL) itemExists: (NSString *) fileOrFolderNameWithoutPath;

// Check if item exists relative to root (/)
+ (BOOL) itemExistsWithPath: (NSString *) fileOrFolderNameWithPath;

// Uses keyed archiving of data.
+ (id) loadApplicationDataFromFlatFile: (NSString *) fileNameWithPath;
+ (BOOL)saveApplicationData: (id) data toFlatFile: (NSString *)fileNameWithPath;

+ (BOOL) deleteFile: (NSString *) fileName withPath: (NSURL *) directoryPath;
+ (BOOL) deleteFileWithPath: (NSURL *) fileNameWithPath;

// fileNamePattern is a Unix style "glob" pattern, e.g., @"Petunia.1LD4z6.*"
+ (BOOL) deleteFilesMatchingPattern: (NSString *) fileNamePattern inDirectory: (NSURL *) directoryPath;

// Creates a unique file name within the directory;
// dir doesn't have a "/" appended.
// Doesn't create the file.
// Returns the new filename, without the directory path.
// Not thread safe.
// E.g., Prefix == "Petunia"
+ (NSString*)createTempFileNameInDirectory:(NSString*)dir withPrefix: (NSString *) prefix andExtension: (NSString *) extension;

+ (BOOL) createDirectoryIfNeeded: (NSURL *) directoryPath;

// In bytes
+ (NSUInteger) fileSize: (NSString *) fileNamePath;

// Give partial path of directory relative to the app home directory, e.g., "Documents/icons". Just the file names are returned. i.e., they don't have the full path relative within the directory given. Returns nil on error.
+ (NSArray *) filesInHomeDirectory: (NSString *) partialPath;

// Returns the paths as NSURL's of the files in the directory. If there are no files, returns an array with zero elements.
+ (NSArray *) filesInBundleDirectory: (NSString *) directory;

// Allow or disallow backup of item to iCloud.
+ (BOOL)addSkipBackupAttributeToItemAtURL:(NSURL *)URL;
+ (BOOL)removeSkipBackupAttributeFromItemAtURL:(NSURL *)URL;

// Pass a filename in the form <filename>.<extension>
// fileNameWithoutExtension is returned as <filename>. (i.e., with the period).
// extension is returned as <extension>
+ (void) breakFileName: (NSString *) fileName intoExtension: (NSString **) extension andFileNameWithoutExtension: (NSString **) fileNameWithoutExtension;

@end


