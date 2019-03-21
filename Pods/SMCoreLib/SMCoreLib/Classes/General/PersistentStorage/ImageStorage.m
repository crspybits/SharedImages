//
//  ImageStorage.m
//  Petunia
//
//  Created by Christopher Prince on 12/9/14.
//  Copyright (c) 2014 Spastic Muffin, LLC. All rights reserved.
//

#import "ImageStorage.h"
#import "UIImage+Resize.h"
#import <ImageIO/ImageIO.h>
// #import "SPASLog.h"
#import "SMAssert.h"

@implementation ImageStorage

+ (instancetype) session;
{
    static ImageStorage* s_sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        s_sharedInstance = [self new];
    });
    
    return s_sharedInstance;
}

+ (UIImage *) getImage: (NSString *) largeImageFileName ofSize: (CGSize) size fromIconDirectory: (NSURL *) iconDirectory withLargeImageDirectory: (NSURL *) largeImageDirectory;
{
    AssertIf(![FileStorage createDirectoryIfNeeded:iconDirectory], @"Could not create icon directory");
    // SPASLogDetail(@"largeImageFileName: %@; size: %@", largeImageFileName, NSStringFromCGSize(size));
    
    NSString *extension = nil;
    NSString *fileNameWithoutExtension = nil;
    [FileStorage breakFileName:largeImageFileName intoExtension:&extension andFileNameWithoutExtension:&fileNameWithoutExtension];
    
    NSUInteger width = size.width;
    NSUInteger height = size.height;
    NSString *smallSizedFileName = [NSString stringWithFormat:@"%@%lux%lu.%@", fileNameWithoutExtension, (unsigned long)width, (unsigned long)height, extension];
    
    UIImage *smallImage = [self imageFromFile:smallSizedFileName withPath:iconDirectory];
    if (smallImage) return smallImage;
    
    // We don't have the small image cached. Create it.
    
    // Get it from the large image directory.
    UIImage *largeImage = [self imageFromFile:largeImageFileName withPath:largeImageDirectory];
    // SPASLogDetail(@"largeImage: %@", largeImageFileName);
    AssertActionIf(!largeImage, @"No large image!", {return nil;});
    
    // Scale the image.
    // Issue: resizedImage: doesn't deal with orientation of image. I'm getting distorted aspect ratio.
    smallImage = [largeImage resizedImage:size interpolationQuality:kCGInterpolationHigh];
    AssertActionIf(!smallImage, @"No scaled image!", {return nil;});
    
    /* 4/23/15; Just got a failure here.
     
     Apr 23 02:57:50 Christopher-Princes-iPad-Air Petunia[3075] <Error>: CGContextConcatCTM: invalid context 0x0. This is a serious error. This application, or a library it uses, is using an invalid context  and is thereby contributing to an overall degradation of system stability and reliability. This notice is a courtesy: please fix this problem. It will become a fatal error in an upcoming update.
     Apr 23 02:57:50 Christopher-Princes-iPad-Air Petunia[3075] <Error>: CGContextSetInterpolationQuality: invalid context 0x0. This is a serious error. This application, or a library it uses, is using an invalid context  and is thereby contributing to an overall degradation of system stability and reliability. This notice is a courtesy: please fix this problem. It will become a fatal error in an upcoming update.
     Apr 23 02:57:50 Christopher-Princes-iPad-Air Petunia[3075] <Error>: CGContextDrawImage: invalid context 0x0. This is a serious error. This application, or a library it uses, is using an invalid context  and is thereby contributing to an overall degradation of system stability and reliability. This notice is a courtesy: please fix this problem. It will become a fatal error in an upcoming update.
     Apr 23 02:57:50 Christopher-Princes-iPad-Air Petunia[3075] <Error>: CGBitmapContextCreateImage: invalid context 0x0. This is a serious error. This application, or a library it uses, is using an invalid context  and is thereby contributing to an overall degradation of system stability and reliability. This notice is a courtesy: please fix this problem. It will become a fatal error in an upcoming update.
     2015-04-23 02:57:50.193 Petunia[3075:715894] +[ImageStorage getImage:ofSize:fromIconDirectory:withLargeImageDirectory:] [Line 52] No scaled image!
     */
    
    BOOL result = [self saveImage:smallImage toFile:smallSizedFileName inDirectory:iconDirectory];
    AssertIf(!result, @"Could not save image");

    // 11/29/17; Sometimes, adding this attibute is failing.
    NSURL *imageNameWithPath = [NSURL URLWithString:smallSizedFileName relativeToURL:iconDirectory];
    result = [FileStorage addSkipBackupAttributeToItemAtURL:imageNameWithPath];
    // SPASLog(@"Could not add skip attribute: %@", imageNameWithPath);

    return smallImage;
}

+ (BOOL) deleteImages: (NSString *) fileName fromIconDirectory: (NSURL *) iconDirectory andLargeImageDirectory: (NSURL *) largeImageDirectory;
{
    NSString *extension = nil;
    NSString *fileNameWithoutExtension = nil;
    [FileStorage breakFileName:fileName intoExtension:&extension andFileNameWithoutExtension:&fileNameWithoutExtension];
    
    BOOL result = YES;
    NSString *pattern = [NSString stringWithFormat:@"%@*", fileNameWithoutExtension];
    
    result = result && [FileStorage deleteFile:fileName withPath:largeImageDirectory];
    result = result && [FileStorage deleteFilesMatchingPattern:pattern inDirectory:iconDirectory];
    return result;
}

+ (UIImage *) imageFromFile:(NSString *) fileName withPath: (NSURL *) fullDirectoryPath;
{
    NSURL *imageNameWithPath = [NSURL URLWithString:fileName relativeToURL:fullDirectoryPath];
    
    // http://stackoverflow.com/questions/7227050/reading-image-from-the-local-folder-in-objective-c
    
    // absoluteString gives the "file:" version; path gives the "/" version.
    
    // Check to see if file exists first
    NSFileManager *fileManager = [NSFileManager defaultManager];
    BOOL fileDoesExist = [fileManager fileExistsAtPath:[imageNameWithPath path]];
    UIImage *image = nil;
    if (fileDoesExist) {
        image = [[UIImage alloc] initWithContentsOfFile:[imageNameWithPath path]];
    }
    
    return image; // nil if file doesn't exist
}

+ (BOOL) saveImage:(UIImage *) image toFile: (NSString *) fileName inDirectory: (NSURL *) directoryPath;
{
    // Create file manager
    NSError *error;
    NSFileManager *fileMgr = [NSFileManager defaultManager];
    
    // http://mobiledevelopertips.com/data-file-management/save-uiimage-object-as-a-png-or-jpeg-file.html
    
    // 11/28/17; I've been having problems with `relativeToURL` paths here.
    // This isn't keeping the last part of the directory name in all cases. Odd.
    // NSURL *imageNameWithPath = [NSURL URLWithString:fileName relativeToURL:directoryPath];
    
    NSURL *imageNameWithPath = [NSURL URLWithString:[NSString stringWithFormat:@"%@/%@", directoryPath.path, fileName]];
        
    // SPASLog(@"JPG file name= %@", imageNameWithPath);
    
    float imageQuality = IMAGE_STORAGE_DEFAULT_IMAGE_QUALITY;
    if ([ImageStorage session].imageQuality) {
        imageQuality = [ImageStorage session].imageQuality();
    }

    // SPASLogDetail(@"imageQuality: %f", imageQuality);
    AssertActionIf(![UIImageJPEGRepresentation(image, imageQuality)
                     writeToFile:[imageNameWithPath path] atomically:YES],
                   @"Could not write JPEG image",
                   {return NO;});
    
    // Let's check to see if file was successfully written...
    
    NSDictionary *fileAttributes = [fileMgr attributesOfItemAtPath:[imageNameWithPath path] error: &error];
    
    // SPASLog(@"fileAttributes: %@", [fileAttributes description]);
    
    if (error != nil) {
        // SPASLog(@"saveImageToFile: ERROR: %@", [error description]);
        return NO;
    }
    
    NSNumber *fileSize = [fileAttributes objectForKey:@"NSFileSize"];
    // SPASLog(@"fileSize = %d", [fileSize intValue]);
    if (0 == fileSize) {
        // Assume that we've got a good file, if file size nonzero
        return NO;
    }
    
    return YES;
}

// See http://stackoverflow.com/questions/12478502/how-to-get-image-metadata-in-ios
+ (CGSize) sizeOfImage:(NSString *) fileName withPath: (NSURL *) fullDirectoryPath;
{
    NSURL *imageNameWithPath = [NSURL URLWithString:fileName relativeToURL:fullDirectoryPath];
    
    CGImageSourceRef source = CGImageSourceCreateWithURL( (CFURLRef) imageNameWithPath, NULL);
    if (!source) return CGSizeZero;
    
    CFDictionaryRef dictRef = CGImageSourceCopyPropertiesAtIndex(source,0,NULL);
    NSDictionary* metadata = (__bridge NSDictionary *)dictRef;
    // SPASLogDetail(@"metadata= %@", metadata);
    CGSize result = CGSizeZero;
    CGFloat width = [metadata[@"PixelWidth"] floatValue];
    CGFloat height = [metadata[@"PixelHeight"] floatValue];
    // SPASLogDetail(@"width= %f, height= %f", width, height);
    
    // The orientation in the metadata does *not* map to UIImageOrientation. Rather, see: https://developer.apple.com/library/ios/documentation/GraphicsImaging/Reference/CGImageProperties_Reference/index.html#//apple_ref/doc/constant_group/Individual_Image_Properties
    // This idea of orientation seems a little odd to me, but it seems it translates to even numbers need to be switched in width/height, odd numbers do not.
    NSUInteger orientation = [metadata[@"Orientation"] integerValue];
    
    switch (orientation) {
        // Comments give "Location of the origin of the image"
        case 1: // Top, left
        case 3: // Bottom, right
        case 5: // Left, top
        case 7: // Right, bottom
            result = CGSizeMake(width, height);
            break;
            
        case 2: // Top, right
        case 4: // Bottom, left
        case 6: // Right, top
        case 8: // Left, bottom
            result = CGSizeMake(height, width);
            break;

        default:
            // 11/24/18; I just ran across an issue: 1) I uploaded an image to Google Drive from iOS, 2) I manually downloaded that image, 3) I reuploaded that image to Google Drive. I then found that the "Orientation" field was gone from the image. I previously had an assert here that forced a crash in this case. Probably shouldn't do that.
            // SPASLogDetail(@"Should not get to here: Image had no orientation!");
            // Just assume a default orientation.
            result = CGSizeMake(width, height);
            break;
    }
    
    CFRelease(source);
    // SPASLogDetail(@"size: %@, orientation: %lu", NSStringFromCGSize(result), (unsigned long)orientation);
    
    return result;
}

/* Example meta data:
    ColorModel = RGB;
    Depth = 8;
    Orientation = 6;
    PixelHeight = 1936;
    PixelWidth = 2592;
    "{Exif}" =     {
        ColorSpace = 1;
        PixelXDimension = 2592;
        PixelYDimension = 1936;
    };
    "{JFIF}" =     {
        DensityUnit = 0;
        JFIFVersion =         (
                               1,
                               1
                               );
        XDensity = 1;
        YDensity = 1;
    };
    "{TIFF}" =     {
        Orientation = 6;
    };
}
*/

@end
