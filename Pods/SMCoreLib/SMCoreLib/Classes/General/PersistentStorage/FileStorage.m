//
//  FileStorage.m
//  Specfly
//
//  Created by Christopher Prince on 2/23/12.
//  Copyright (c) 2012 Spastic Muffin, LLC. All rights reserved.
//

// See 
// http://stackoverflow.com/questions/8727508/ios-persistent-storage-strategy

#import "FileStorage.h"
#import "SPASLog.h"
#import "SMAssert.h"
#import "NSArray+Globbing.h"

@implementation FileStorage

+ (NSString *)pathToItem: (NSString *) fileOrFolderNameWithoutPath;
{
    static NSString *path = nil;
    NSArray *p = NSSearchPathForDirectoriesInDomains(
                NSDocumentDirectory, NSUserDomainMask, YES);
    //if (PersistentStorageDebug) SPASLog(@"paths= %@", [p description]);
    path = [[p objectAtIndex:0] stringByAppendingPathComponent:fileOrFolderNameWithoutPath];
    SPASLog(@"path= %@", path);
    return path;
}

+ (NSURL *)urlOfItem: (NSString *) fileOrFolderNameWithoutPath;
{
    NSString *path = [self pathToItem:fileOrFolderNameWithoutPath];
    NSURL *url = [NSURL fileURLWithPath:path];
    return url;
}

+ (BOOL) itemExistsWithPath: (NSString *) fileOrFolderNameWithPath;
{
    NSFileManager *fileMgr = [NSFileManager defaultManager];
    return [fileMgr fileExistsAtPath:fileOrFolderNameWithPath];
}

+ (BOOL) itemExists: (NSString *) fileOrFolderNameWithoutPath;
{
    NSString *path = [self pathToItem:fileOrFolderNameWithoutPath];
    return [self itemExistsWithPath:path];
}

+ (id) loadApplicationDataFromFlatFile: (NSString *) fileName {
    NSData *archivedData = [NSData dataWithContentsOfFile:fileName];
    if (archivedData) {
        return [NSKeyedUnarchiver unarchiveObjectWithData:archivedData];
    } else {
        return nil;
    }
}

+ (BOOL)saveApplicationData: (id) data toFlatFile: (NSString *)fileName {
    NSData *archivedData = [NSKeyedArchiver archivedDataWithRootObject:data];
    BOOL result = [archivedData writeToFile:fileName atomically:YES];
    if (! result) {
        SPASLogFile(@"PersistentStorage.saveApplicationData: failed writing file: %@",fileName);
    }
    return result;
}

// http://stackoverflow.com/questions/7759220/nsfilemanager-unique-file-names

+ (NSString*)createTempFileNameInDirectory:(NSString*)dir withPrefix: (NSString *) prefix andExtension: (NSString *) extension;
{    
    // 8/29/14; Changed to using mkstemps. I don't want the file open, or created, but I do want to have a .jpg extension on the files. The extension will make it easier to give the users access to the files (e.g., in an XML export).
    NSString* templateStr =
        [NSString stringWithFormat:@"%@/%@.XXXXXX.%@",
         dir, prefix, extension];
    char template[[templateStr length] + 1];
    strcpy(template, [templateStr cStringUsingEncoding:NSASCIIStringEncoding]);
    NSUInteger suffixLen = [extension length] + 1; // +1 for period.
    
    int fd = mkstemps(template, (int) suffixLen);
    if (-1 == fd) {
        SPASLog(@"Could not create file in directory %@", dir);
        return nil;
    }
    
    if (close(fd) == -1) {
        SPASLog(@"Could not close file %@", dir);
        unlink(template);
        return nil;
    }
    
    if (unlink(template) == -1) {
        SPASLog(@"Could not remove file %@", dir);
        unlink(template);
        return nil;
    }
    
    NSMutableString *result = [NSMutableString stringWithCString:template encoding:NSASCIIStringEncoding];
    
    // Remove the "dir" part of the string, so I don't have absolute
    // path names; I prefer relative path names; might give me more
    // portability later.
    // The +1 below is because dir doesn't have the '/', but I want
    // to remove the '/'
    result = [NSMutableString stringWithString:[result substringFromIndex:[dir length] +1]];
    
    return result;
}

// Delete a file with full path name
+ (BOOL) deleteFile: (NSString *) fileName withPath: (NSURL *) directoryPath;
{
    NSURL *fileNameWithPath = [NSURL URLWithString:fileName relativeToURL:directoryPath];
    return [self deleteFileWithPath:fileNameWithPath];
}

+ (BOOL) deleteFileWithPath: (NSURL *) fileNameWithPath;
{
    return [self deleteFileWithStringPath:[fileNameWithPath path]];
}

+ (BOOL) deleteFileWithStringPath: (NSString *) fileNameWithPath;
{
    // Create file manager
    NSError *error;
    NSFileManager *fileMgr = [NSFileManager defaultManager];
    
    bool done = [fileMgr removeItemAtPath:fileNameWithPath error:&error];
    if (! done) {
        SPASLog(@"deleteFileWithPath: ERROR: Could not delete file: %@", fileNameWithPath);
        return NO;
    } else {
        SPASLog(@"deleteFileWithPath: SUCCESS: Deleted file: %@", fileNameWithPath);
        return YES;
    }
}

+ (BOOL) deleteFilesMatchingPattern: (NSString *) fileNamePattern inDirectory: (NSURL *) directoryPath;
{
    NSArray *files = [NSArray arrayWithFilesMatchingPattern:fileNamePattern inDirectory:[directoryPath path]];
    BOOL result = YES;
    
    for (NSString *fileNameWithPath in files) {
        // Keep going even if we fail on one deletion. Result will go NO and stay NO in this case.
        result = result && [self deleteFileWithStringPath:fileNameWithPath];
    }
    
    return result;
}

+ (BOOL) createDirectoryIfNeeded: (NSURL *) directoryPath;
{
    /* It seems that in some iOS versions (seems iOS6), if the path is not
     present, directories will be created. HOWEVER, in iOS5 this is not
     true. I just got an error in iOS5 on a new installation where the
     icons directory is not created. So, let's go ahead and create the
     directory if it's not there.
     */
    NSError *error;
    NSFileManager *fileMgr = [NSFileManager defaultManager];
    NSArray *dirContents = [fileMgr contentsOfDirectoryAtPath:[directoryPath path] error:&error];
    if (nil == dirContents) {
        SPASLogDetail(@"error= %@", [error description]);
        // Directory does not exist
        bool done = [fileMgr createDirectoryAtPath:[directoryPath path] withIntermediateDirectories:YES attributes:nil error:&error];
        if (! done) {
            SPASLog(@"Could not create directory");
            return NO;
        }
    }
    
    return YES;
}

+ (NSUInteger) fileSize: (NSString *) fileNamePath {
    NSFileManager *fileMgr = [NSFileManager defaultManager];
    NSError *error;
    NSDictionary *fileAttributes = [fileMgr attributesOfItemAtPath:fileNamePath error:&error];
    if (! error) {
        return [fileAttributes[NSFileSize] integerValue];
    } else {
        return 0;
    }
}

+ (NSArray *) filesInBundleDirectory: (NSString *) directory;
{
    NSURL *bundleURL = [[NSBundle mainBundle] bundleURL];
    NSURL *dirURL = [bundleURL URLByAppendingPathComponent:directory];
    NSError *error = nil;
    NSArray *dirContents = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:[dirURL path] error:&error];
    // While the docs for contentsOfDirectoryAtPath say it returns paths, it actually just returns file names. But, I really want the full URL's.
    SPASLogDetail(@"%@; error= %@", dirContents, error);
    NSMutableArray *urls = [NSMutableArray array];
    for (NSString *filename in dirContents) {
        NSURL *urlForFile = [dirURL URLByAppendingPathComponent:filename];
        [urls addObject:urlForFile];
    }
    SPASLogDetail(@"URLs: %@", urls);
    return urls;
}

+ (NSArray *) filesInHomeDirectory: (NSString *) partialPath;
{
    NSError *error = nil;
    NSFileManager *fileMgr = [NSFileManager defaultManager];
    NSString  *dirPath = [NSHomeDirectory() stringByAppendingPathComponent:partialPath];
    NSArray *files = [fileMgr contentsOfDirectoryAtPath:dirPath error:&error];
    if (error) {
        SPASLogFile(@"error: %@", error);
        return nil;
    }
    return files;
}

// From: https://developer.apple.com/library/ios/qa/qa1719/_index.html

+ (BOOL)setSkipBackupAttributeToItemAtURL:(NSURL *)URL toValue: (BOOL) exclude;
{
    if (![[NSFileManager defaultManager] fileExistsAtPath: [URL path]]) {
        return NO;
    }
    
    NSError *error = nil;
    BOOL success = [URL setResourceValue: [NSNumber numberWithBool: exclude]
                                  forKey: NSURLIsExcludedFromBackupKey error: &error];
    if(!success){
        SPASLogFile(@"Error: %@", error);
    }
    return success;
}

+ (BOOL)addSkipBackupAttributeToItemAtURL:(NSURL *)URL;
{
    return [self setSkipBackupAttributeToItemAtURL:URL toValue:YES];
}

+ (BOOL)removeSkipBackupAttributeFromItemAtURL:(NSURL *)URL;
{
    return [self setSkipBackupAttributeToItemAtURL:URL toValue:NO];
}

+ (void) breakFileName: (NSString *) fileName intoExtension: (NSString **) extension andFileNameWithoutExtension: (NSString **) fileNameWithoutExtension;
{
    *extension = [fileName pathExtension];
    *fileNameWithoutExtension =
    [fileName substringToIndex:[fileName length] - [*extension length]];
}

@end
