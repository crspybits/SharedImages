//
//  ImageStorage.h
//  Petunia
//
//  Created by Christopher Prince on 12/9/14.
//  Copyright (c) 2014 Spastic Muffin, LLC. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>
#import <UIKit/UIKit.h>
#import "FileStorage.h"

// JPEG image storage.

@interface ImageStorage : NSObject

+ (instancetype) session;

#define IMAGE_STORAGE_DEFAULT_IMAGE_QUALITY 0.75

// Setup a block that can be called to get the image quality that should be used for saving an image. Block should return a value between 0 (lowest quality) and 1 (highest quality.
@property (nonatomic, strong) CGFloat (^imageQuality)(void);

// The returned size takes into account the orientation of the image.
+ (CGSize) sizeOfImage:(NSString *) fileName withPath: (NSURL *) fullDirectoryPath;

+ (UIImage *) imageFromFile:(NSString *) fileName withPath: (NSURL *) fullDirectoryPath;
+ (BOOL) saveImage:(UIImage *) image toFile: (NSString *) fileName inDirectory: (NSURL *) directoryPath;

/* fileName is given in the form <filename>.<ext>
 This implements a kind caching. First, it looks for a file with name:
 <filename>.<W>x<H>.<ext>
 in the icon directory, where <W> and <H> are the width and height given in size, but converted to integer values.
 If this image is found, it is read, and returned.
 If this image is not found, it looks for a file of name <filename>.<ext> in the large image directory. If this is found, it scales the image to the size given, and saves the image to the file name as given above in the icon directory. The small image created is given the "don't backup in iCloud" attribute.
 */
+ (UIImage *) getImage: (NSString *) fileName ofSize: (CGSize) size fromIconDirectory: (NSURL *) iconDirectory withLargeImageDirectory: (NSURL *) largeImageDirectory;

/* Like the above getImage: method, this method is given a fileName in the form <filename>.<ext>
 File <filename>.<ext> is deleted from the large image directory, if present.
 Any files of the form <filename>.* are deleted from the icon directory.
 */
+ (BOOL) deleteImages: (NSString *) fileName fromIconDirectory: (NSURL *) iconDirectory andLargeImageDirectory: (NSURL *) largeImageDirectory;

@end
