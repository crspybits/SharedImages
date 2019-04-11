//
//  LMGeocoder.m
//  LMGeocoder
//
//  Created by LMinh on 31/05/2014.
//  Copyright (c) 2014 LMinh. All rights reserved.
//

#import "LMGeocoder.h"
#import "LMAddress.h"

static NSString * const kLMGeocoderErrorDomain = @"LMGeocoderError";

#define kGoogleAPIReverseGeocodingURL(lat, lng) [NSString stringWithFormat:@"https://maps.googleapis.com/maps/api/geocode/json?latlng=%f,%f&sensor=true", lat, lng];
#define kGoogleAPIGeocodingURL(address)         [NSString stringWithFormat:@"https://maps.googleapis.com/maps/api/geocode/json?address=%@&sensor=true", address];
#define kGoogleAPIURLWithKey(url, key)          [NSString stringWithFormat:@"%@&key=%@", url, key];

@interface LMGeocoder ()

@property (nonatomic, readwrite, assign) BOOL isGeocoding;
@property (nonatomic, strong) CLGeocoder *appleGeocoder;
@property (nonatomic, strong) NSURLSessionDataTask *googleGeocoderTask;

@end

@interface NSURLSession (Synchronous)

+ (NSData *) sendSynchronousRequest: (NSURLRequest *) request
                  returningResponse: (__autoreleasing NSURLResponse **) responsePtr
                              error: (__autoreleasing NSError **) errorPtr;

@end

@implementation LMGeocoder


#pragma mark - INIT

+ (LMGeocoder *)sharedInstance
{
    static LMGeocoder *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[LMGeocoder alloc] init];
    });
    return sharedInstance;
}

+ (LMGeocoder *)geocoder
{
    return [[LMGeocoder alloc] init];
}

- (id)init
{
    self = [super init];
    if (self != nil) {
        self.appleGeocoder = [[CLGeocoder alloc] init];
    }
    return self;
}


#pragma mark - GEOCODE

- (void)geocodeAddressString:(NSString *)addressString
                     service:(LMGeocoderService)service
           completionHandler:(LMGeocodeCallback)handler
{
    if (handler == nil) {
        return;
    }
    
    self.isGeocoding = YES;
    
    // Check address string
    if (addressString == nil || addressString.length == 0)
    {
        // Invalid address string --> Return error
        NSError *error = [NSError errorWithDomain:kLMGeocoderErrorDomain
                                             code:kLMGeocoderErrorInvalidAddressString
                                         userInfo:nil];
        
        self.isGeocoding = NO;
        handler(nil, error);
    }
    else
    {
        // Valid address string --> Check service
        switch (service)
        {
            case kLMGeocoderGoogleService:
            {
                // Geocode using Google service
                NSString *urlString = kGoogleAPIGeocodingURL(addressString);
                if (self.googleAPIKey != nil) {
                    urlString = kGoogleAPIURLWithKey(urlString, self.googleAPIKey)
                }
                [self buildAsynchronousRequestFromURLString:urlString
                                          completionHandler:^(NSArray<LMAddress *> * _Nullable results, NSError * _Nullable error) {
                  
                    self.isGeocoding = NO;

                    handler(results, error);
                }];
                break;
            }
            case kLMGeocoderAppleService:
            {
                // Geocode using Apple service
                [self.appleGeocoder geocodeAddressString:addressString
                                       completionHandler:^(NSArray *placemarks, NSError *error) {
                                           
                                           self.isGeocoding = NO;
                                           
                                           if (!error && placemarks.count) {
                                               // Request successful --> Parse response results
                                               NSArray * results = [self parseGeocodingResponseResults: placemarks
                                                                                               service: kLMGeocoderAppleService];
                                               handler(results, nil);
                                           }
                                           else {
                                               // Request failed --> Return error
                                               handler(nil, error);
                                           }
                                       }];
                break;
            }
            default:
                break;
        }
    }
}

- (nullable NSArray *)geocodeAtGoogleAddressString:(NSString *)addressString
                                             error:(NSError **)error {
    
    if (addressString == nil
        || addressString.length == 0) {
        // Invalid address string --> Return
        *error = [NSError errorWithDomain:kLMGeocoderErrorDomain
                                     code:kLMGeocoderErrorInvalidAddressString
                                 userInfo:nil];
        return nil;
    }
    
    self.isGeocoding = YES;
    
    // Valid address string --> Geocode using Google service
    NSString *urlString = kGoogleAPIGeocodingURL(addressString);
    if (self.googleAPIKey != nil) {
        urlString = kGoogleAPIURLWithKey(urlString, self.googleAPIKey)
    }
    NSArray *finalResults = [self buildSynchronousRequestFromURLString:urlString];
    
    self.isGeocoding = NO;
    
    return finalResults;
}

- (nullable NSArray *)geocodeAddressString:(nonnull NSString *)addressString
                                   service:(LMGeocoderService)service
                                     error:(NSError **)error
{
    // Check address string
    if (addressString == nil || addressString.length == 0)
    {
        // Invalid address string --> Return
        *error = [NSError errorWithDomain:kLMGeocoderErrorDomain
                                     code:kLMGeocoderErrorInvalidAddressString
                                 userInfo:nil];
        return nil;
    }
    
    switch (service)
    {
        case kLMGeocoderGoogleService: {
                self.isGeocoding = YES;
            
                // Valid address string --> Geocode using Google service
                NSString *urlString = kGoogleAPIGeocodingURL(addressString);
                if (self.googleAPIKey != nil) {
                    urlString = kGoogleAPIURLWithKey(urlString, self.googleAPIKey)
                }
                NSArray *finalResults = [self buildSynchronousRequestFromURLString:urlString];
            
                self.isGeocoding = NO;
            
                return finalResults;
            
        } break;
            
        case kLMGeocoderAppleService: {
            
            self.isGeocoding = YES;
            
            __block NSArray * results = nil;
            __block NSError * blockError = nil;
            
//            dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
//            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                [self.appleGeocoder geocodeAddressString: addressString
                                       completionHandler: ^(NSArray *placemarks, NSError *appleError) {
                                           
                       self.isGeocoding = NO;
                       
                       blockError = appleError;
                       NSLog(@"%@", appleError);
                       NSLog(@"placemarks %@", placemarks);
                       if (!appleError && placemarks.count) {
                           // Request successful --> Parse response results
                           results = [self parseGeocodingResponseResults: placemarks
                                                                 service: kLMGeocoderAppleService];
                       }
                       
                                           CFRunLoopRun();
//                       dispatch_semaphore_signal(semaphore);
                }];
//            });
            
//            dispatch_time_t timeoutTime = dispatch_time(DISPATCH_TIME_NOW, 20 * NSEC_PER_SEC);
//            dispatch_semaphore_wait(semaphore, timeoutTime);
            
            *error = blockError;
            return results;
            
        }    break;
    }
}


#pragma mark - REVERSE GEOCODE

- (void)reverseGeocodeCoordinate:(CLLocationCoordinate2D)coordinate
                         service:(LMGeocoderService)service
               completionHandler:(LMGeocodeCallback)handler
{
    
    if (handler == nil) {
        return;
    }
    
    self.isGeocoding = YES;
    
    // Check location coordinate
    if (!CLLocationCoordinate2DIsValid(coordinate))
    {
        // Invalid location coordinate --> Return error
        NSError *error = [NSError errorWithDomain:kLMGeocoderErrorDomain
                                             code:kLMGeocoderErrorInvalidCoordinate
                                         userInfo:nil];
        
        self.isGeocoding = NO;
        handler(nil, error);
    }
    else
    {
        // Valid location coordinate --> Check service
        switch (service)
        {
            case kLMGeocoderGoogleService:
            {
                // Reverse geocode using Google service
                NSString *urlString = kGoogleAPIReverseGeocodingURL(coordinate.latitude, coordinate.longitude);
                if (self.googleAPIKey != nil) {
                    urlString = kGoogleAPIURLWithKey(urlString, self.googleAPIKey)
                }
                [self buildAsynchronousRequestFromURLString:urlString
                                          completionHandler:^(NSArray<LMAddress *> * _Nullable results, NSError * _Nullable error) {
                                              
                                              self.isGeocoding = NO;
                                              
                                               handler(results, error);
                                              
                                          }];
                break;
            }
            case kLMGeocoderAppleService:
            {
                // Reverse geocode using Apple service
                CLLocation *location = [[CLLocation alloc] initWithLatitude:coordinate.latitude
                                                                  longitude:coordinate.longitude];
                [self.appleGeocoder reverseGeocodeLocation:location
                                         completionHandler:^(NSArray *placemarks, NSError *error) {
                                             
                                             self.isGeocoding = NO;
                                             
                                             if (!error && placemarks.count) {
                                                 // Request successful --> Parse response results
                                                 NSArray * results = [self parseGeocodingResponseResults: placemarks
                                                                                                 service: kLMGeocoderAppleService];
                                                 handler(results, nil);
                                             }
                                             else {
                                                 // Request failed --> Return error
                                                 handler(nil, error);
                                             }
                                         }];
                break;
            }
            default:
                break;
        }
    }
}

- (nullable NSArray *)reverseGeocodeCoordinate:(CLLocationCoordinate2D)coordinate
                                       service:(LMGeocoderService)service
                                         error:(NSError **)error
{
    // Check location coordinate
    if (!CLLocationCoordinate2DIsValid(coordinate))
    {
        // Invalid location coordinate --> Return
        *error = [NSError errorWithDomain:kLMGeocoderErrorDomain
                                     code:kLMGeocoderErrorInvalidCoordinate
                                 userInfo:nil];
        return nil;
    }
    else
    {
        // Valid location coordinate --> Reverse geocode using Google service
        NSString *urlString = kGoogleAPIReverseGeocodingURL(coordinate.latitude, coordinate.longitude);
        if (self.googleAPIKey != nil) {
            urlString = kGoogleAPIURLWithKey(urlString, self.googleAPIKey)
        }
        NSArray *finalResults = [self buildSynchronousRequestFromURLString:urlString];
        return finalResults;
    }
}


#pragma mark - CANCEL

- (void)cancelGeocode
{
    if (self.appleGeocoder) {
        [self.appleGeocoder cancelGeocode];
    }
    
    if (self.googleGeocoderTask) {
        [self.googleGeocoderTask cancel];
    }
}


#pragma mark - CONNECTION STUFF

- (void)buildAsynchronousRequestFromURLString:(NSString *)urlString
                            completionHandler:(LMGeocodeCallback)handler
{
    urlString = [urlString stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]];
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:[NSURL URLWithString:urlString]];
    
    NSURLSessionConfiguration *configuration = [NSURLSessionConfiguration defaultSessionConfiguration];
    NSURLSession *session = [NSURLSession sessionWithConfiguration:configuration];
    self.googleGeocoderTask = [session dataTaskWithRequest:request
                                         completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
                                             dispatch_async(dispatch_get_main_queue(), ^{
                                                 if (!error && data)
                                                 {
                                                     // Request successful --> Parse response to JSON
                                                     NSError *parsingError = nil;
                                                     NSDictionary *result = [NSJSONSerialization JSONObjectWithData:data
                                                                                                            options:NSJSONReadingAllowFragments
                                                                                                              error:&parsingError];
                                                     if (!parsingError && result)
                                                     {
                                                         // Parse successful --> Check status value
                                                         NSString *status = [result valueForKey:@"status"];
                                                         if ([status isEqualToString:@"OK"])
                                                         {
                                                             // Status OK --> Parse response results
                                                             NSArray *locationDicts = [result objectForKey:@"results"];
                                                             NSArray *finalResults = [self parseGeocodingResponseResults:locationDicts service:kLMGeocoderGoogleService];
                                                             
                                                             if (handler) {
                                                                 handler(finalResults, nil);
                                                             }
                                                         }
                                                         else
                                                         {
                                                             // Other statuses --> Return error
                                                             if (handler) {
                                                                 handler(nil, error);
                                                             }
                                                         }
                                                     }
                                                     else
                                                     {
                                                         // Parse failed --> Return error
                                                         if (handler) {
                                                             handler(nil, error);
                                                         }
                                                     }
                                                 }
                                                 else
                                                 {
                                                     // Request failed --> Return error
                                                     if (handler) {
                                                         handler(nil, error);
                                                     }
                                                 }
                                             });
                                         }];
    [self.googleGeocoderTask resume];
}

- (NSArray *)buildSynchronousRequestFromURLString:(NSString *)urlString
{
    urlString = [urlString stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]];
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:[NSURL URLWithString:urlString]];
    
    NSURLResponse *response = nil;
    NSError *error = nil;
    
    NSData * data = [NSURLSession sendSynchronousRequest: request
                                       returningResponse: &response
                                                   error: &error];
    if (!error && data)
    {
        NSError *parsingError = nil;
        NSDictionary *result = [NSJSONSerialization JSONObjectWithData:data
                                                               options:NSJSONReadingAllowFragments
                                                                 error:&parsingError];
        if (!parsingError && result)
        {
            NSString *status = [result objectForKey:@"status"];
            if ([status isEqualToString:@"OK"])
            {
                // Status OK --> Parse response results
                NSArray *locationDicts = [result objectForKey:@"results"];
                NSArray *finalResults = [self parseGeocodingResponseResults:locationDicts service:kLMGeocoderGoogleService];
                
                return finalResults;
            }
        }
    }
    
    return nil;
}


#pragma mark - PARSE RESULT DATA

- (NSArray *)parseGeocodingResponseResults:(NSArray *)responseResults service:(LMGeocoderService)service
{
    NSMutableArray *finalResults = [NSMutableArray new];
    
    for (id responseResult in responseResults) {
        LMAddress *address = [[LMAddress alloc] initWithLocationData:responseResult forServiceType:service];
        [finalResults addObject:address];
    }
    
    return finalResults;
}

@end

@implementation NSURLSession (Synchronous)

// https://stackoverflow.com/questions/26784315/can-i-somehow-do-a-synchronous-http-request-via-nsurlsession-in-swift
+ (NSData *) sendSynchronousRequest: (NSURLRequest *) request
                  returningResponse: (__autoreleasing NSURLResponse **) responsePtr
                              error: (__autoreleasing NSError **) errorPtr {
    dispatch_semaphore_t    sem;
    __block NSData *        result;
    
    result = nil;
    
    sem = dispatch_semaphore_create(0);
    
    [[[NSURLSession sharedSession] dataTaskWithRequest:request
                                     completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (errorPtr != NULL) {
            *errorPtr = error;
        }
        if (responsePtr != NULL) {
            *responsePtr = response;
        }
        if (error == nil) {
            result = data;
        }
        dispatch_semaphore_signal(sem);
    }] resume];
    
    dispatch_semaphore_wait(sem, DISPATCH_TIME_FOREVER);
    
    return result;
}

@end
