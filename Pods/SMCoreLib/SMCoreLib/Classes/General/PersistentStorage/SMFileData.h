//
//  SMFileData.h
//  Petunia
//
//  Created by Christopher Prince on 5/1/13.
//  Copyright (c) 2013 Christopher Prince. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface SMFileData : NSObject

// Read data from file.
- (id) initWithFileName: (NSString *) fileName;

// Save to file.
- (BOOL) save;

// Helper function. Sort an array of NSString names.
+ (void) sortArrayOfNames: (NSMutableArray *) array;

// Reload the data from a file; can be useful if some other instance of this class modified the data.
- (BOOL) reload;

// For subclasses only; Made this a property to access from Swift.
@property (nonatomic, strong) id data;

@end
