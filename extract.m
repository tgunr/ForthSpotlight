#import <CoreFoundation/CoreFoundation.h>
#import <CoreServices/CoreServices.h> 
#import <CoreFoundation/CFPlugInCOM.h>
#import <Foundation/Foundation.h>
#import <RegexKit/RegexKit.h>
#import <stdio.h>
#import <syslog.h>

#import "extract.h"

/* -----------------------------------------------------------------------------
   Step 1
   Set the UTI types the importer supports
  
   Modify the CFBundleDocumentTypes entry in Info.plist to contain
   an array of Uniform Type Identifiers (UTI) for the LSItemContentTypes 
   that your importer can handle
  
   ----------------------------------------------------------------------------- */

/* -----------------------------------------------------------------------------
   Step 2 
   Implement the GetMetadataForFile function
  
   Implement the GetMetadataForFile function below to scrape the relevant
   metadata from your document and return it as a CFDictionary using standard keys
   (defined in MDItem.h) whenever possible.
   ----------------------------------------------------------------------------- */

/* -----------------------------------------------------------------------------
   Step 3 (optional) 
   If you have defined new attributes, update the schema.xml file
  
   Edit the schema.xml file to include the metadata keys that your importer returns.
   Add them to the <allattrs> and <displayattrs> elements.
  
   Add any custom types that your importer requires to the <attributes> element
  
   <attribute name="com_mycompany_metadatakey" type="CFString" multivalued="true"/>
  
   ----------------------------------------------------------------------------- */

Boolean assertRegex(NSString * stringToSearch, NSString* regexString) {
    NSPredicate *regex = [NSPredicate predicateWithFormat:@"SELF MATCHES %@", regexString];
    return [regex evaluateWithObject:stringToSearch];    
}
/* -----------------------------------------------------------------------------
    Get metadata attributes from file
   
   This function's job is to extract useful information your file format supports
   and return it as a dictionary
   ----------------------------------------------------------------------------- */

Boolean extract(void* thisInterface, 
			   CFMutableDictionaryRef attributes, 
			   CFStringRef contentTypeUTI,
			   CFStringRef pathToFile)
{
    /* Pull any available metadata from the file at the specified path */
    /* Return the attribute keys and attribute values in the dict */
    /* Return TRUE if successful, FALSE if there was no data provided */
    
    Boolean success=NO;
	bool foundInitial=false, headerLine=false;
	char line[256];
	char path[2048];
	FILE * fh = NULL;
    NSRange range, theRange;
	NSString *version, *date, *time, *author, *contains;
	NSArray *array, *data;
	
	NSMutableString *bigString = [[NSMutableString alloc] init];
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	
	// setup for the file
	// NSLog(@"Forth Source File: %@", pathToFile);
	char *pathPtr = (char *)CFStringGetCStringPtr(pathToFile, kCFStringEncodingUnicode);
	// NSLog(@"pathPtr: %x", pathPtr);
	if (pathPtr == NULL) {
		if (CFStringGetCString(pathToFile, path, 2048, kCFStringEncodingASCII)) {
			// NSLog(@"path: %s", path);
			syslog(LOG_ALERT, "ForthSpotlight: %s", path);
			fh = fopen(path, "r");
		}
	} else {
		// NSLog(@"pathPtr: %s", pathPtr);
		syslog(LOG_ALERT, "ForthSpotlight: %s", pathPtr);
		fh = fopen(pathPtr, "r");
	}
	if (fh) {
		do {	// Only search the uninterrupted header lines
			
			// Don't assume that there is an autorelease pool around the calling of this function.
			NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
			fgets(line, 256, fh);
			// syslog(LOG_ALERT, "Forth File: %s", line);
			
			// accumulate line
			NSString *theString = [[[NSMutableString alloc] initWithCString:line encoding:NSNEXTSTEPStringEncoding] autorelease];
			[bigString appendString:theString];
			
			range.location = 0;
			range.length = strlen(line);
			
			// syslog(LOG_ALERT, "foundInitial = %d", foundInitial);
			if (!foundInitial) {
				// Look for 'File:` in the line
				theRange = [theString rangeOfString:@"File:\t" options: NSLiteralSearch range: range];
				// syslog(LOG_ALERT, "Forth File: theRange = %d %d", theRange.location, theRange.length);
				if (theRange.location > 0 && theRange.location == NSNotFound) {
					goto nextline;
				} else {
					// found it, now split line at the ',`
					array = [theString componentsSeparatedByString:@",v "];
					if ([array count] == 2) {
						data = [array objectAtIndex: 1];
						array = [(NSString *)data componentsSeparatedByString:@" "];
						if ([array count]) {
							version = [array objectAtIndex: 0];
							date = [array objectAtIndex: 1];
							time = [array objectAtIndex: 2];
							author = [array objectAtIndex: 3];
							//// syslog(LOG_ALERT, "author[0]= %s %c", [author UTF8String], [author characterAtIndex: 0]);
							if ([author characterAtIndex: 0] == '(') {
								// syslog(LOG_ALERT, "Forth File: range = %d %d", range.location, range.length);
								range.location = 1;
								range.length = [author length] - 1;
								// syslog(LOG_ALERT, "Forth File: range = %d %d", range.location, range.length);
								author = [author substringWithRange: range];
							}
//							// syslog(LOG_ALERT, "Forth File: %s %s %s %s", 
//								[version cString] 
//								[date cString], 
//								[time cString],
//								[author cString]);
							[(NSMutableDictionary *)attributes setObject:version
								forKey:(NSString *)kMDItemVersion];
							// could walk the log and gather all authors but I don't see much point, will just take last checkin author
							[(NSMutableDictionary *)attributes setObject:[NSArray arrayWithObject:author]
								forKey:(NSString *)kMDItemAuthors];
							[(NSMutableDictionary *)attributes setObject:@"Forth Source File"
								forKey:(NSString *)kMDItemKind];
							// return YES so that the attributes are imported
							success=YES;
							// Now look for other stuff:
							foundInitial = 1;
							goto nextline;
						}
					}
				}
			} else {
				// Look for other data after the initial header line
				// For now, just the Contains: line
				theRange = [theString rangeOfString:@"Contains:\t" options: NSLiteralSearch range: range];
				if (theRange.location > 0 && theRange.location == NSNotFound) {
					goto nextline;
				} else {
					// found it, now split line at Contains:
					array = [theString componentsSeparatedByString:@"Contains:\t"];
					if ([array count]) {
						contains = [array objectAtIndex: 1];
						if ([contains hasSuffix: @"\n"]) {
							array = [contains componentsSeparatedByString:@"\n"];
							contains = [array objectAtIndex: 0];
						}
						[(NSMutableDictionary *)attributes setObject:contains
							forKey:(NSString *)kMDItemDescription];
					}
				}
			}
			
nextline:
			headerLine = [theString hasPrefix: @"\\"];
			[pool release];
		} while (headerLine && !feof(fh));
		
		NSMutableArray *definitions = [[NSMutableArray alloc] initWithCapacity: 128];
		
		// Now parse for definitions
		do {
			NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
			fgets(line, 256, fh);
			NSString *theLine = [[[NSString alloc] initWithCString:line encoding:NSNEXTSTEPStringEncoding] autorelease];
			
			if (assertRegex(theLine, @"^:\\s*(\\S+)\\s+.*") || 
				assertRegex(theLine, @"^\\s*(code|CODE)\\s+(\\S+)\\s+.*") ||
				assertRegex(theLine, @"^\\s*(tcode|TCODE)\\s+(\\S+)\\s+.*")) {
				NSArray * lineComponents = [theLine componentsSeparatedByString: @" "];
				NSString *definition = [lineComponents objectAtIndex: 1];
				[definitions addObject: definition];			
			}
			[bigString appendString:theLine];
			[pool release];
		} while (!feof(fh));

		// store definitions into metadata
		if ([definitions count] > 0) {
			[(NSMutableDictionary *)attributes setObject:definitions forKey:@"public.forth-source.definitions"];
			int i;
			for(i=0; i < [definitions count]; i++) {
				NSLog(@"Def %d = %@", i, [definitions objectAtIndex: i]); 
			}
		}
		[definitions release];
			
		[(NSMutableDictionary *)attributes setObject:bigString forKey: (id)kMDItemTextContent];
		[bigString release];
		
		fclose(fh);
	}
	[pool release];
    return success;
}

