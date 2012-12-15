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

#import "FRFeedbackController.h"
#import "FRFeedbackReporter.h"
#import "FRUploader.h"
#import "FRCommand.h"
#import "FRApplication.h"
#import "FRCrashLogFinder.h"
#import "FRSystemProfile.h"
#import "FRConstants.h"

#import "NSMutableDictionary+Additions.h"

#import <SystemConfiguration/SCNetwork.h>
#import <SystemConfiguration/SCNetworkReachability.h>


@implementation FRFeedbackController

#pragma mark Construction

- (id) init
{
    self = [super initWithWindowNibName:@"FeedbackReporter"];
    if (self != nil) {
        detailsShown = YES;
    }
    return self;
}

- (void) awakeFromNib
{
    NSString* name = NSFullUserName();
    if (name) {
        [nameField setStringValue:name];
    }
    NSString* email = [[NSUserDefaults standardUserDefaults] stringForKey:@"GHEmailAddress"];
    if (email) {
        [emailField setStringValue:email];
    }
}

#pragma mark Destruction



#pragma mark Accessors

- (id) delegate
{
    return delegate;
}

- (void) setDelegate:(id) pDelegate
{
    delegate = pDelegate;
}

- (void) setHeading:(NSString*)message
{
    [headingField setStringValue:message];
}

- (void) setSubheading:(NSString *)informativeText
{
    [subheadingField setStringValue:informativeText];
}

- (void) setMessage:(NSString*)message
{
    [messageView setString:message];
}

- (void) setException:(NSString*)exception
{
    [exceptionView setString:exception];
}

- (void) setType:(NSString*)theType
{
    if (theType != type) {
        type = theType;
    }
}

#pragma mark information gathering

- (NSArray*) systemProfile
{
    static NSArray *systemProfile = nil;

    if (systemProfile == nil) {
        systemProfile = [FRSystemProfile discover];
    }

    return systemProfile;
}

- (NSString*) systemProfileAsString
{
    NSMutableString *string = [NSMutableString string];
    NSArray *dicts = [self systemProfile];
    NSUInteger i = [dicts count];
    while(i--) {
        NSDictionary *dict = [dicts objectAtIndex:i];
        [string appendFormat:@"%@ = %@\n", [dict objectForKey:@"key"], [dict objectForKey:@"value"]];
    }
    return string;
}

- (NSString*) crashLog
{
    NSDate *lastSubmissionDate = [[NSUserDefaults standardUserDefaults] valueForKey:DEFAULTS_KEY_LASTSUBMISSIONDATE];

    NSArray *crashFiles = [FRCrashLogFinder findCrashLogsSince:lastSubmissionDate];

    NSUInteger i = [crashFiles count];

    if (i == 1) {
        if (lastSubmissionDate == nil) {
            NSLog(@"Found a crash file");
        } else {
            NSLog(@"Found a crash file earlier than latest submission on %@", lastSubmissionDate);
        }
        NSError *error = nil;
        NSString *result = [NSString stringWithContentsOfFile:[crashFiles lastObject] encoding: NSUTF8StringEncoding error:&error];
        if (result == nil) {
            NSLog(@"Failed to read crash file: %@", error);
            return @"";
        }
        return result;
    }

    if (lastSubmissionDate == nil) {
        NSLog(@"Found %lu crash files", (unsigned long)i);
    } else {
        NSLog(@"Found %lu crash files earlier than latest submission on %@", (unsigned long)i, lastSubmissionDate);
    }
    
    NSFileManager *fileManager = [NSFileManager defaultManager];

    NSDate *newest = nil;
    NSInteger newestIndex = -1;

    while(i--) {
    
        NSString *crashFile = [crashFiles objectAtIndex:i];
		NSError* error = nil;
		NSDictionary *fileAttributes = [fileManager attributesOfItemAtPath:crashFile error:&error];
		if (!fileAttributes) {
			NSLog(@"Error while fetching file attributes: %@", [error localizedDescription]);
		}
        NSDate *fileModDate = [fileAttributes objectForKey:NSFileModificationDate];

        NSLog(@"CrashLog: %@", crashFile);

        if ([fileModDate laterDate:newest] == fileModDate) {
            newest = fileModDate;
            newestIndex = i;
        }

    }
    
    if (newestIndex != -1) {
        NSString *newestCrashFile = [crashFiles objectAtIndex:newestIndex];

        NSLog(@"Picking CrashLog: %@", newestCrashFile);

        NSError *error = nil;
        NSString *result = [NSString stringWithContentsOfFile:newestCrashFile encoding: NSUTF8StringEncoding error:&error];
        if (result == nil) {
            NSLog(@"Failed to read crash file: %@", error);
            return @"";
        }
        return result;
    }

    return @"";
}

- (NSString*) scriptLog
{
    NSMutableString *scriptLog = [NSMutableString string];

    NSString *scriptPath = [[NSBundle mainBundle] pathForResource:FILE_SHELLSCRIPT ofType:@"sh"];

    if ([[NSFileManager defaultManager] fileExistsAtPath:scriptPath]) {

        FRCommand *cmd = [[FRCommand alloc] initWithPath:scriptPath];
        [cmd setOutput:scriptLog];
        [cmd setError:scriptLog];
        int ret = [cmd execute];

        NSLog(@"Script exit code = %d", ret);
        
    } /* else {
        NSLog(@"No custom script to execute");
    }
    */

    return scriptLog;
}

- (NSString*) preferences
{
    NSMutableDictionary *preferences = [[[NSUserDefaults standardUserDefaults] persistentDomainForName:[FRApplication applicationIdentifier]] mutableCopy];
    
    if (preferences == nil) {
        return @"";
    }

    [preferences removeObjectForKey:DEFAULTS_KEY_SENDEREMAIL];
    [preferences removeObjectForKey:DEFAULTS_KEY_SENDERNAME];

    if ([delegate respondsToSelector:@selector(anonymizePreferencesForFeedbackReport:)]) {
        preferences = [delegate anonymizePreferencesForFeedbackReport:preferences];
    }

    return [NSString stringWithFormat:@"%@", preferences];
}


#pragma mark UI Actions

- (void) showDetails:(BOOL)show animate:(BOOL)animate
{
    if (detailsShown == show) {
        return;
    }
    
    NSSize fullSize = NSMakeSize(455, 302);
    
    NSRect windowFrame = [[self window] frame];
        
    if (show) {

        windowFrame.origin.y -= fullSize.height;
        windowFrame.size.height += fullSize.height;
        [[self window] setFrame: windowFrame
                        display: YES
                        animate: animate];

    } else {
        windowFrame.origin.y += fullSize.height;
        windowFrame.size.height -= fullSize.height;
        [[self window] setFrame: windowFrame
                        display: YES
                        animate: animate];
        
    }
    
    detailsShown = show;    
}

- (IBAction) showDetails:(id)sender
{
    BOOL show = [[sender objectValue] boolValue];
	[self showDetails:show animate:YES];
}

- (IBAction) cancel:(id)sender
{
    [uploader cancel], uploader = nil;
    
    [self close];
}

- (IBAction) send:(id)sender
{
    if (uploader != nil) {
        NSLog(@"Still uploading");
        return;
    }
            
    NSString *target = @"https://secure.goldenhillsoftware.com/noindex/mail/crashreport.php";
    
    if ([[[FRFeedbackReporter sharedReporter] delegate] respondsToSelector:@selector(targetUrlForFeedbackReport)]) {
        target = [[[FRFeedbackReporter sharedReporter] delegate] targetUrlForFeedbackReport];
    }
    
    NSURL *url = [NSURL URLWithString:target];

    SCNetworkConnectionFlags reachabilityFlags = 0;
    
	NSString *host = [url host];
    const char *hostname = [host UTF8String];

    SCNetworkReachabilityRef reachability = SCNetworkReachabilityCreateWithName(NULL, hostname);
    Boolean reachabilityResult = SCNetworkReachabilityGetFlags(reachability, &reachabilityFlags);
    CFRelease(reachability);
    
	// Prevent premature garbage collection (UTF8String returns an inner pointer).
	[host self];
	
    BOOL reachable = reachabilityResult
        &&  (reachabilityFlags & kSCNetworkFlagsReachable)
        && !(reachabilityFlags & kSCNetworkFlagsConnectionRequired)
        && !(reachabilityFlags & kSCNetworkFlagsConnectionAutomatic)
        && !(reachabilityFlags & kSCNetworkFlagsInterventionRequired);
    
    if (!reachable) {
        NSInteger alertResult = [[NSAlert alertWithMessageText:FRLocalizedString(@"Feedback Host Not Reachable", nil)
												 defaultButton:FRLocalizedString(@"Proceed Anyway", nil)
											   alternateButton:FRLocalizedString(@"Cancel", nil)
												   otherButton:nil
									 informativeTextWithFormat:FRLocalizedString(@"You may not be able to send feedback because %@ isn't reachable.", nil), host
								  ] runModal];

        if (alertResult != NSAlertDefaultReturn) {
            return;
        }
    }

    uploader = [[FRUploader alloc] initWithTarget:target delegate:self];
    
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
	
    [dict setValidString:[nameField stringValue]
				  forKey:POST_KEY_NAME];
	
   [dict setValidString:[emailField stringValue]
				  forKey:POST_KEY_EMAIL];
	
    [dict setValidString:[messageView string]
				  forKey:POST_KEY_MESSAGE];
	
	[dict setValidString:type
				  forKey:POST_KEY_TYPE];
	
	[dict setValidString:[FRApplication applicationName]
				  forKey:POST_APPNAME];
	
	[dict setValidString:[FRApplication applicationEdition]
				  forKey:POST_EDITION];
	
	[dict setValidString:[FRApplication applicationLongVersion]
				  forKey:POST_KEY_VERSION_LONG];
	
	[dict setValidString:[FRApplication applicationShortVersion]
				  forKey:POST_KEY_VERSION_SHORT];
	
	[dict setValidString:[FRApplication applicationBundleVersion]
				  forKey:POST_KEY_VERSION_BUNDLE];
	
	[dict setValidString:[FRApplication applicationVersion]
				  forKey:POST_KEY_VERSION];
	
	if ([sendDetailsCheckbox state] == NSOnState) {
		if ([delegate respondsToSelector:@selector(customParametersForFeedbackReport)]) {
			[dict addEntriesFromDictionary:[delegate customParametersForFeedbackReport]];
		}
		
		[dict setValidString:[self systemProfileAsString]
					  forKey:POST_KEY_SYSTEM];
		
		[dict setValidString:[crashesView string]
					  forKey:POST_KEY_CRASHES];
		
		[dict setValidString:[scriptView string]
					  forKey:POST_KEY_SHELL];
		
		[dict setValidString:[preferencesView string]
					  forKey:POST_KEY_PREFERENCES];
		
		[dict setValidString:[exceptionView string]
					  forKey:POST_KEY_EXCEPTION];
	}
    
    if ([emailField stringValue]) {
        [[NSUserDefaults standardUserDefaults] setObject:[emailField stringValue] forKey:@"GHEmailAddress"];
    }
    
    NSLog(@"Sending feedback to %@", target);
    
    [uploader postAndNotify:dict];
}

- (void) uploaderStarted:(FRUploader*)pUploader
{
    // NSLog(@"Upload started");

    [indicator setHidden:NO];
    [indicator startAnimation:self];
    
    [messageView setEditable:NO];
    [sendButton setEnabled:NO];
}

- (void) uploaderFailed:(FRUploader*)pUploader withError:(NSError*)error
{
    NSLog(@"Upload failed: %@", error);

    [indicator stopAnimation:self];
    [indicator setHidden:YES];

    uploader = nil;
    
    [messageView setEditable:YES];
    [sendButton setEnabled:YES];

    NSAlert *alert = [[NSAlert alloc] init];
    [alert addButtonWithTitle:FRLocalizedString(@"OK", nil)];
    [alert setMessageText:FRLocalizedString(@"Sorry, failed to submit your feedback to the server.", nil)];
    [alert setInformativeText:[NSString stringWithFormat:FRLocalizedString(@"Error: %@", nil), [error localizedDescription]]];
    [alert setAlertStyle:NSWarningAlertStyle];
    [alert runModal];

    [self close];
}

- (void) uploaderFinished:(FRUploader*)pUploader
{
    // NSLog(@"Upload finished");

    [indicator stopAnimation:self];
    [indicator setHidden:YES];

    uploader = nil;

    [messageView setEditable:YES];
    [sendButton setEnabled:YES];


    [[NSUserDefaults standardUserDefaults] setValue:[NSDate date]
                                             forKey:DEFAULTS_KEY_LASTSUBMISSIONDATE];

    [[NSUserDefaults standardUserDefaults] setObject:[emailField stringValue]
                                              forKey:DEFAULTS_KEY_SENDEREMAIL];
    [[NSUserDefaults standardUserDefaults] setObject:[nameField stringValue] forKey:DEFAULTS_KEY_SENDERNAME];

    if (floor(NSAppKitVersionNumber) > NSAppKitVersionNumber10_7) {
        NSUserNotificationCenter* ctr = [NSUserNotificationCenter defaultUserNotificationCenter];
        NSUserNotification* not = [[NSUserNotification alloc] init];
        [not setTitle:NSLocalizedString(@"Thank you", @"")];
        [not setInformativeText:NSLocalizedString(@"Thank you for the crash report.", @"")];
        [not setHasActionButton:NO];
        [ctr deliverNotification:not];
    }

    [self close];
}

- (void) windowWillClose: (NSNotification *) n
{
    [uploader cancel];
}

- (void) windowDidLoad
{
    [[self window] setDelegate:self];

    [emailLabel setStringValue:FRLocalizedString(@"Email address:", nil)];
    
    [tabCrash setLabel:FRLocalizedString(@"CrashLog", nil)];
    [tabScript setLabel:FRLocalizedString(@"Script", nil)];
    [tabPreferences setLabel:FRLocalizedString(@"Preferences", nil)];
    [tabException setLabel:FRLocalizedString(@"Exception", nil)];
    
    [sendButton setTitle:FRLocalizedString(@"Send", nil)];
    [cancelButton setTitle:FRLocalizedString(@"Cancel", nil)];

    [[crashesView textContainer] setContainerSize:NSMakeSize(CGFLOAT_MAX, CGFLOAT_MAX)];
    [[crashesView textContainer] setWidthTracksTextView:NO];
    [crashesView setString:@""];
    [[scriptView textContainer] setContainerSize:NSMakeSize(CGFLOAT_MAX, CGFLOAT_MAX)];
    [[scriptView textContainer] setWidthTracksTextView:NO];
    [scriptView setString:@""];
    [[preferencesView textContainer] setContainerSize:NSMakeSize(CGFLOAT_MAX, CGFLOAT_MAX)];
    [[preferencesView textContainer] setWidthTracksTextView:NO];
    [preferencesView setString:@""];
    [[exceptionView textContainer] setContainerSize:NSMakeSize(CGFLOAT_MAX, CGFLOAT_MAX)];
    [[exceptionView textContainer] setWidthTracksTextView:NO];
    [exceptionView setString:@""];
}

- (void) stopSpinner
{
    [indicator stopAnimation:self];
    [indicator setHidden:YES];
    [sendButton setEnabled:YES];
}

- (void) addTabViewItem:(NSTabViewItem*)theTabViewItem
{
    [tabView insertTabViewItem:theTabViewItem atIndex:1];
}

- (void) populate
{
    @autoreleasepool {

        NSString *crashLog = [self crashLog];
        if ([crashLog length] > 0) {
            [self performSelectorOnMainThread:@selector(addTabViewItem:) withObject:tabCrash waitUntilDone:YES];
            [crashesView performSelectorOnMainThread:@selector(setString:) withObject:crashLog waitUntilDone:YES];
        }

        NSString *scriptLog = [self scriptLog];
        if ([scriptLog length] > 0) {
            [self performSelectorOnMainThread:@selector(addTabViewItem:) withObject:tabScript waitUntilDone:YES];
            [scriptView performSelectorOnMainThread:@selector(setString:) withObject:scriptLog waitUntilDone:YES];
        }

        NSString *preferences = [self preferences];
        if ([preferences length] > 0) {
            [self performSelectorOnMainThread:@selector(addTabViewItem:) withObject:tabPreferences waitUntilDone:YES];
            [preferencesView performSelectorOnMainThread:@selector(setString:) withObject:preferences waitUntilDone:YES];
        }

        [self performSelectorOnMainThread:@selector(stopSpinner) withObject:self waitUntilDone:YES];
    
    }
}

- (void) reset
{
    [tabView removeTabViewItem:tabCrash];
    [tabView removeTabViewItem:tabScript];
    [tabView removeTabViewItem:tabPreferences];
    [tabView removeTabViewItem:tabException];

    

    NSString *email = [[NSUserDefaults standardUserDefaults] stringForKey:DEFAULTS_KEY_SENDEREMAIL];
    if (email) {
        [emailField setStringValue:email];
    }
    NSString* name = [[NSUserDefaults standardUserDefaults] stringForKey:DEFAULTS_KEY_SENDERNAME];
    if (name) {
        [nameField setStringValue:name];
    }

    [headingField setStringValue:@""];
    [messageView setString:@""];
    [exceptionView setString:@""];

    [self showDetails:NO animate:NO];
    [detailsButton setIntValue:NO];    

    [indicator setHidden:NO];
    [indicator startAnimation:self];    
    [sendButton setEnabled:NO];

	//	setup 'send details' checkbox...
	[sendDetailsCheckbox setTitle:FRLocalizedString(@"Send details", nil)];
	[sendDetailsCheckbox setState:NSOnState];
	NSString *sendDetailsIsOptional = [[[NSBundle mainBundle] infoDictionary] valueForKey:PLIST_KEY_SENDDETAILSISOPTIONAL];
	if (sendDetailsIsOptional && [sendDetailsIsOptional isEqualToString:@"YES"]) {
		[detailsLabel setHidden:YES];
		[sendDetailsCheckbox setHidden:NO];
	} else {
		[detailsLabel setHidden:NO];
		[sendDetailsCheckbox setHidden:YES];
	}
}

- (void) showWindow:(id)sender
{
    if (type == FR_FEEDBACK) {
		[messageLabel setStringValue:FRLocalizedString(@"Feedback comment label", nil)];
    } else {
        [messageLabel setStringValue:FRLocalizedString(@"Comments:", nil)];
    }

    if ([[exceptionView string] length] != 0) {
        [tabView insertTabViewItem:tabException atIndex:1];
        [tabView selectTabViewItemWithIdentifier:@"Exception"];
    } else {
        [tabView selectTabViewItemWithIdentifier:@"System"];
    }

    [NSThread detachNewThreadSelector:@selector(populate) toTarget:self withObject:nil];
    
    [super showWindow:sender];
}

- (BOOL) isShown
{
    return [[self window] isVisible];
}


@end
