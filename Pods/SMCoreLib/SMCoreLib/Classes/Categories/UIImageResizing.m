#import "UIImageResizing.h"
#import "UIImage+Resize.h"
#import "SPASLog.h"

// http://stackoverflow.com/questions/2658738/the-simplest-way-to-resize-an-uiimage
@implementation UIImage (ResizeVersion1)

// Returns a new image, scaled to size.
- (UIImage*)scaleToSize:(CGSize)size {
    UIGraphicsBeginImageContext(size);

    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextTranslateCTM(context, 0.0, size.height);
    CGContextScaleCTM(context, 1.0, -1.0);

    CGContextDrawImage(context, CGRectMake(0.0f, 0.0f, size.width, size.height), self.CGImage);

    UIImage* scaledImage = UIGraphicsGetImageFromCurrentImageContext();
    
    SPASLog(@"UIImageResizing.scaleToSize: orientation: %ld", (long) [scaledImage imageOrientation]);
    
    UIGraphicsEndImageContext();

    return scaledImage;
}

- (UIImage*)scaleToHeight:(NSInteger) height {
    CGFloat oldHeight = self.size.height;
    CGFloat scale = (height/oldHeight);
    CGFloat width = self.size.width * scale;
    SPASLog(@"width = %f", width);
    CGSize size = CGSizeMake(width, height);
    return [self scaleToSize:size];
}

// Code from Apple's Location app that scales an image to keep
// the image at constant height
/*
 // Create a thumbnail version of the image for the event object.
 CGSize size = selectedImage.size;
 CGFloat ratio = 0;
 if (size.width > size.height) {
    ratio = 44.0 / size.width;
 }
 else {
    ratio = 44.0 / size.height;
 }
 CGRect rect = CGRectMake(0.0, 0.0, ratio * size.width, ratio * size.height);
 */
- (NSInteger) heightForWidth: (NSInteger) width {
    CGFloat oldWidth = self.size.width;
    CGFloat scale = (width/oldWidth);
    CGFloat height = self.size.height * scale;
    
    return height;
}

/* I had problems initially scaling an image to fit an icon size. I had
 problems with rotation (orientation). Initially, the image was not
 oriented in the correct manner, and this also resulted in an icon
 that was disorted in aspect ratio. I solved this with imageWithCGImage
 as below passing along the original orientation to preserve that, 
 during the scaling.
 */
/*
- (UIImage *) scaleImageToIcon {
    // For some reason the scale is the inverse of what I would expect.
    // E.g., a scale of 0.1 causes an increase in size by a factor
    // of 10!!
    float scale = self.size.width/ICON_WIDTH;
    
    UIImage *scaledImage = [UIImage imageWithCGImage:[self CGImage] scale:scale orientation:self.imageOrientation];

    SPASLog(@"scaleImageToIcon: original: height= %f, width= %f",
        self.size.height, self.size.width);
    SPASLog(@"scaleImageToIcon: scale: %f; height= %f, width= %f",
          scale, scaledImage.size.height, scaledImage.size.width);
    
    return scaledImage;
}
*/

// Much of first part of this code from:
// http://iphonedevsdk.com/forum/iphone-sdk-development/7307-resizing-a-photo-to-a-new-uiimage.html
/*
- (UIImage *) scaleImageToIcon {
    float scale = ICON_WIDTH/self.size.width;
    float width = ICON_WIDTH;
    float height = scale * self.size.height;
    
    switch (self.imageOrientation) {
    case UIImageOrientationUp:
        break;
        break;
            
    case UIImageOrientationLeft:
    case UIImageOrientationRight:
        break;
            
    case UIImageOrientationUpMirrored:
        break;
    case UIImageOrientationDownMirrored:
        break;
    case UIImageOrientationLeftMirrored:
        break;
    case UIImageOrientationRightMirrored:
        break;
    default:
        // Not much to do!
        break;
    }
    
    CGImageRef imageRef = [self CGImage];
	CGImageAlphaInfo alphaInfo = CGImageGetAlphaInfo(imageRef);
	
	//if (alphaInfo == kCGImageAlphaNone)
    alphaInfo = kCGImageAlphaNoneSkipLast;
	
	CGContextRef bitmap = CGBitmapContextCreate(NULL, width, height, CGImageGetBitsPerComponent(imageRef), 4 * width, CGImageGetColorSpace(imageRef), alphaInfo);
	CGContextDrawImage(bitmap, CGRectMake(0, 0, width, height), imageRef);
	CGImageRef ref = CGBitmapContextCreateImage(bitmap);
    
    // Scale of 1.0 says: Don't scale it.
    // For some reason the scale is the inverse of what I would expect.
    // E.g., a scale of 0.1 causes an increase in size by a factor
    // of 10!!
    // Furthermore, this scaling doesn't actually appear to change
    // the underlying image data. When I write this image
    // out to a file, it's the same size as the full size image.
    UIImage *scaledImage = [UIImage imageWithCGImage:ref scale:1.0 orientation:self.imageOrientation];
	
	CGContextRelease(bitmap);
	CGImageRelease(ref);
    
    if (UIImageResizing2Debug) SPASLog(@"scaleImageToIcon: original: height= %f, width= %f",
          self.size.height, self.size.width);
    if (UIImageResizing2Debug) SPASLog(@"scaleImageToIcon: scale: %f; height= %f, width= %f",
          scale, scaledImage.size.height, scaledImage.size.width);
    
    return scaledImage;
}
*/

- (UIImage *) scaleImageToIcon {
    float scale = ICON_WIDTH/self.size.width;
    CGSize newSize;
    newSize.width = ICON_WIDTH;
    newSize.height = scale * self.size.height;
    
    UIImage *iconImage = [self resizedImage:newSize
                       interpolationQuality:kCGInterpolationHigh];
    
    SPASLog(@"scaleImageToIcon: original: height= %f, width= %f",
          self.size.height, self.size.width);
    SPASLog(@"scaleImageToIcon: scale: %f; height= %f, width= %f",
          scale, iconImage.size.height, iconImage.size.width);
    
    return iconImage;
}

@end
