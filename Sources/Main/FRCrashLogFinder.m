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

#import "FRCrashLogFinder.h"
#import "FRApplication.h"

@implementation FRCrashLogFinder

+ (BOOL)file:(NSString*)path isNewerThan:(NSDate*)date
{
    NSFileManager *fileManager = [NSFileManager defaultManager];

    if (![fileManager fileExistsAtPath:path]) {
        return NO;
    }

    if (!date) {
        return YES;
    }

	NSError* error = nil;
    NSDate* fileDate = [[fileManager attributesOfItemAtPath:path error:&error] fileModificationDate];
	if (!fileDate) {
		NSLog(@"Error while fetching file attributes: %@", [error localizedDescription]);
	}

    if ([date compare:fileDate] == NSOrderedDescending) {
        return NO;
    }
    
    return YES;
}

+ (NSArray*) findCrashLogsSince:(NSDate*)date
{
    NSMutableArray *files = [NSMutableArray array];

    NSFileManager *fileManager = [NSFileManager defaultManager];
    
    NSString* homeDir = NSHomeDirectory();
    NSInteger libIndex = [homeDir rangeOfString:@"/Library/Containers/"].location;
    if (libIndex != NSNotFound) {
        homeDir = [homeDir substringToIndex:libIndex];
    }
    NSString* crashLogDir = [homeDir stringByAppendingPathComponent:@"Library/Logs/DiagnosticReports"];

    NSDirectoryEnumerator *enumerator = nil;
    NSString *file = nil;
    
    if ([fileManager fileExistsAtPath:crashLogDir]) {
        enumerator  = [fileManager enumeratorAtPath:crashLogDir];
        while ((file = [enumerator nextObject])) {
            NSString* expectedPrefix = [[FRApplication applicationName] stringByAppendingString:@"_"];
            if ([[file pathExtension] isEqualToString:@"crash"] && [[file stringByDeletingPathExtension] hasPrefix:expectedPrefix]) {

                file = [crashLogDir stringByAppendingPathComponent:file];
                if ([self file:file isNewerThan:date]) {
                    [files addObject:file];
                }
            }
        }


    }
    
    return files;
}

@end
