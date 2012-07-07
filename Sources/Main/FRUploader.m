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


- (NSString*) stringByUrlEncoding:(NSString*) argStr {
	return (__bridge_transfer  NSString *)CFURLCreateStringByAddingPercentEscapes(
                                                                                 NULL,
                                                                                 (__bridge CFStringRef)argStr,
                                                                                 NULL,
                                                                                 (CFStringRef)@"!*'();:@&=+$,/?%#[]",
                                                                                 kCFStringEncodingUTF8 );
}

- (NSData *) generateFormData: (NSDictionary *)dict
{
    
    NSMutableString* description = [NSMutableString string];
    
    for( NSString* key in [dict allKeys] ) {
        if ([description length] != 0) {
            [description appendString:@"&"];
        }
        [description appendFormat:@"%@=%@", [self stringByUrlEncoding:key], [self stringByUrlEncoding:dict[key]]];
    }
    return [description dataUsingEncoding:NSUTF8StringEncoding];
}


- (NSString*) post:(NSDictionary*)dict
{
    NSData *formData = [self generateFormData:dict];

    NSLog(@"Posting %lu bytes to %@", (unsigned long)[formData length], target);

    NSMutableURLRequest *post = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:target]];
    
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

    return [[NSString alloc] initWithData:result
                                  encoding:NSUTF8StringEncoding];
}

- (void) postAndNotify:(NSDictionary*)dict
{
    
    NSData *formData = [self generateFormData:dict ];
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
    [responseData appendData:data];
}

- (void) connection:(NSURLConnection *)pConnection didFailWithError:(NSError *)error
{
    if ([delegate respondsToSelector:@selector(uploaderFailed:withError:)]) {

        [delegate performSelector:@selector(uploaderFailed:withError:) withObject:self withObject:error];
    }
        
}

- (void) connectionDidFinishLoading: (NSURLConnection *)pConnection
{
    if ([delegate respondsToSelector: @selector(uploaderFinished:)]) {
        [delegate performSelector:@selector(uploaderFinished:) withObject:self];
    }
    
}


- (void) cancel
{
    [connection cancel];
    connection = nil;
}

- (NSString*) response
{
    return [[NSString alloc] initWithData:responseData
                                  encoding:NSUTF8StringEncoding];
}

@end
