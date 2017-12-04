//
//  NSURL+Extras.m
//  Petunia
//
//  Created by Christopher Prince on 3/27/15.
//  Copyright (c) 2015 Spastic Muffin, LLC. All rights reserved.
//

#import "NSURL+Extras.h"

@implementation NSURL (Extras)

// Code from: http://stackoverflow.com/questions/8756683/best-way-to-parse-url-string-to-get-values-for-keys

- (NSDictionary *) queryItems;
{
    NSMutableDictionary *queryStrings = [[NSMutableDictionary alloc] init];
    for (NSString *qs in [self.query componentsSeparatedByString:@"&"]) {
        // Get the parameter name
        NSString *key = [[qs componentsSeparatedByString:@"="] objectAtIndex:0];
        // Get the parameter value
        NSString *value = [[qs componentsSeparatedByString:@"="] objectAtIndex:1];
        value = [value stringByReplacingOccurrencesOfString:@"+" withString:@" "];
        value = [value stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
        
        queryStrings[key] = value;
    }
    
    return queryStrings;
}

@end
