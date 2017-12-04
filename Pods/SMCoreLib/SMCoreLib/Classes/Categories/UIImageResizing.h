// // http://stackoverflow.com/questions/2658738/the-simplest-way-to-resize-an-uiimage

#import <UIKit/UIKit.h>

@interface UIImage (ResizeVersion1)
- (UIImage*)scaleToSize:(CGSize)size;

// Scale the width proportionate to this height
- (UIImage*)scaleToHeight:(NSInteger) height;

#define DEFAULT_ICON_HEIGHT 44
#define ICON_WIDTH 100

// If I make the image this wide, how high will it have to be,
// proportionately?
- (NSInteger) heightForWidth: (NSInteger) width;

// Makes a copy of the image, scales it, and returns it.
// I have had a great deal of problem with scaling down to icons
// and managing to retain the orientation of the original image!!
- (UIImage *) scaleImageToIcon;
@end

/* Example
 UIImage* image = [UIImage imageNamed:@"largeImage.png"];
 UIImage* smallImage = [image scaleToSize:CGSizeMake(100.0f,100.0f)];
*/