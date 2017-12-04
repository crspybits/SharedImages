#import "NSArray+Globbing.h"
#include <glob.h>

@implementation NSArray (Globbing)

+ (NSArray*) arrayWithFilesMatchingPattern: (NSString*) pattern inDirectory: (NSString*) directory {

    NSMutableArray* files = [NSMutableArray array];
    glob_t gt;
    NSString* globPathComponent = [NSString stringWithFormat: @"/%@", pattern];
    NSString* expandedDirectory = [directory stringByExpandingTildeInPath];
    const char* fullPattern = [[expandedDirectory stringByAppendingPathComponent: globPathComponent] UTF8String];
    if (glob(fullPattern, 0, NULL, &gt) == 0) {
        int i;
        for (i=0; i<gt.gl_matchc; i++) {
            NSUInteger len = strlen(gt.gl_pathv[i]);
            NSString* filename = [[NSFileManager defaultManager] stringWithFileSystemRepresentation: gt.gl_pathv[i] length: len];
            [files addObject: filename];
        }
    }
    globfree(&gt);
    return [NSArray arrayWithArray: files];
}

@end
