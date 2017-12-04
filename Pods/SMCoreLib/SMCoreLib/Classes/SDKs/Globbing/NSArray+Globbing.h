// From https://gist.github.com/bkyle/293959

#import <Foundation/Foundation.h>

@interface NSArray (Globbing)

// Returns the full path name of the file as NSString's.
+ (NSArray*) arrayWithFilesMatchingPattern: (NSString*) pattern inDirectory: (NSString*) directory;

@end
