//
//  FileData.m
//  Petunia
//
//  Created by Christopher Prince on 5/1/13.
//  Copyright (c) 2013 Christopher Prince. All rights reserved.
//

#import "SMFileData.h"
#import "SPASLog.h"

#ifdef SMCOMMONLIB
#import <SMCommon/FileStorage.h>
#else
#import "FileStorage.h"
#endif

@interface SMFileData ()
@property (nonatomic, strong) NSString *fileName;
@end

@implementation SMFileData

+ (void) sortArrayOfNames: (NSMutableArray *) array {
    [array sortUsingComparator:^NSComparisonResult(id a, id b) {
        NSString *aStr = (NSString *) a;
        NSString *bStr = (NSString *) b;
        return [aStr compare:bStr];
    }];
}

- (id) initWithFileName: (NSString *) fileName {
    self = [super init];
    if (self) {
        _fileName = fileName;
        self.data = [FileStorage loadApplicationDataFromFlatFile:[FileStorage pathToItem:self.fileName]];
    }
    return self;
}

// Save to file.
- (BOOL) save {
    
    BOOL result = [FileStorage saveApplicationData:self.data toFlatFile:[FileStorage pathToItem:self.fileName]];
    if (!result) {
        SPASLogFile(@"Error writing to file!");
    }
    return result;
}

- (BOOL) reload {
    self.data = [FileStorage loadApplicationDataFromFlatFile:[FileStorage pathToItem:self.fileName]];
    BOOL result;
    if (self.data) {
        result = YES;
    } else {
        result = NO;
        SPASLogFile(@"Error reading from file!");
    }
    return result;
}

@end
