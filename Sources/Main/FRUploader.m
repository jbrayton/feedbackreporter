/*
 * Copyright 2008-2010, Torsten Curdt
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#import "FRUploader.h"


@implementation FRUploader

- (id) initWithTarget:(NSString*)pTarget delegate:(id<FRUploaderDelegate>)pDelegate
{
    self = [super init];
    if (self != nil) {
        target = pTarget;
        delegate = pDelegate;
        responseData = [[NSMutableData alloc] init];
    }
    
    return self;
}

- (void) dealloc
{
    [responseData release];
    
    [super dealloc];
}

- (NSData *) generateFormData: (NSDictionary *)dict
{
    
    NSMutableString* description = [NSMutableString string];
    
    for( NSString* key in [dict allKeys] ) {
        [description appendFormat:@"%@\n%@\n\n", key, [dict objectForKey:key]];
    }
    
    NSDictionary* info = [[NSBundle mainBundle] infoDictionary];
    
    NSString* post = [NSString stringWithFormat:@"ScoutUserName=%@&ScoutProject=%@&ScoutArea=%@&FriendlyResponse=0&Description=%@&Extra=%@", 
                      [[info objectForKey:@"FRFeedbackReporter.ScoutUserName"] stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding], 
                      [[info objectForKey:@"FRFeedbackReporter.ScoutProject"] stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding], 
                      [[info objectForKey:@"FRFeedbackReporter.ScoutArea"] stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding], 
                      [NSString stringWithFormat:@"Feedback - %@", [[NSDate date] description]],
                      [description stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]];
    return [post dataUsingEncoding:NSUTF8StringEncoding];
}


- (NSString*) post:(NSDictionary*)dict
{
    NSData *formData = [self generateFormData:dict];

    NSLog(@"Posting %lu bytes to %@", (unsigned long)[formData length], target);

    NSMutableURLRequest *post = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:target]];
    
   // [post addValue:@"application/x-www-form-urlencoded" forHTTPHeaderField: @"Content-Type"];
    [post setHTTPMethod: @"POST"];
    [post setCachePolicy:NSURLRequestReloadIgnoringCacheData];
    [post setValue:@"application/x-www-form-urlencoded" forHTTPHeaderField:@"Content-Type"];
    [post setHTTPBody:formData];

    NSURLResponse *response = nil;
    NSError *error = nil;
    NSData *result = [NSURLConnection sendSynchronousRequest: post
                                           returningResponse: &response
                                                       error: &error];

    if(result == nil) {
        NSLog(@"Post failed. Error: %ld, Description: %@", (long)[error code], [error localizedDescription]);
    }

    return [[[NSString alloc] initWithData:result
                                  encoding:NSUTF8StringEncoding] autorelease];
}

- (void) postAndNotify:(NSDictionary*)dict
{
    NSData *formData = [self generateFormData:dict ];

    NSLog(@"Posting %lu bytes to %@", (unsigned long)[formData length], target);

    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:target]];
    
    [request setHTTPMethod: @"POST"];
    [request setCachePolicy:NSURLRequestReloadIgnoringCacheData];
    [request setValue:@"application/x-www-form-urlencoded" forHTTPHeaderField:@"Content-Type"];
    [request setHTTPBody:formData];

    connection = [[NSURLConnection alloc] initWithRequest:request delegate:self];

    if (connection != nil) {
        if ([delegate respondsToSelector:@selector(uploaderStarted:)]) {
            [delegate performSelector:@selector(uploaderStarted:) withObject:self];
        }
        
    } else {
        if ([delegate respondsToSelector:@selector(uploaderFailed:withError:)]) {

            [delegate performSelector:@selector(uploaderFailed:withError:) withObject:self
                withObject:[NSError errorWithDomain:@"Failed to establish connection" code:0 userInfo:nil]];

        }
    }
}



- (void) connection: (NSURLConnection *)pConnection didReceiveData: (NSData *)data
{
    NSLog(@"Connection received data");

    [responseData appendData:data];
}

- (void) connection:(NSURLConnection *)pConnection didFailWithError:(NSError *)error
{
    NSLog(@"Connection failed");
    
    if ([delegate respondsToSelector:@selector(uploaderFailed:withError:)]) {

        [delegate performSelector:@selector(uploaderFailed:withError:) withObject:self withObject:error];
    }
        
    [connection autorelease];
}

- (void) connectionDidFinishLoading: (NSURLConnection *)pConnection
{
    // NSLog(@"Connection finished");

    if ([delegate respondsToSelector: @selector(uploaderFinished:)]) {
        [delegate performSelector:@selector(uploaderFinished:) withObject:self];
    }
    
    [connection autorelease];
}


- (void) cancel
{
    [connection cancel];
    [connection autorelease], connection = nil;
}

- (NSString*) response
{
    return [[[NSString alloc] initWithData:responseData
                                  encoding:NSUTF8StringEncoding] autorelease];
}

@end
