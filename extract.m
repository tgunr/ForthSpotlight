#import <CoreFoundation/CoreFoundation.h>
#import <CoreServices/CoreServices.h> 
#import <CoreFoundation/CFPlugInCOM.h>
#import <Foundation/Foundation.h>
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
	Boolean foundTagLine=NO;
	char path[2048];
	FILE * fh = NULL;
    NSRange range, theRange;
	NSString *version, *author, *contains;
//	NSString *date, *time;
	NSArray * lineComponents;
	NSArray * lineSubComponents;
#ifndef TESTING
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
#endif
	NSMutableArray *definitions = [[NSMutableArray alloc] initWithCapacity: 128];
	NSMutableString	*sourceContent = [NSMutableString stringWithCapacity: 4096];
	
#ifndef TESTING
	// Grab our plist for file extensions
	NSBundle * myBundle = [NSBundle bundleWithIdentifier: @"com.polymicrosystems.spotlight.forth"];
	NSDictionary * bundleDictionary = [myBundle infoDictionary];
	NSArray * myDocuentTypes = [bundleDictionary objectForKey:@"CFBundleDocumentTypes"];
	NSDictionary * myDocuentTypesDictionary = [myDocuentTypes objectAtIndex:0];
	NSArray * myFileExtensions = [myDocuentTypesDictionary objectForKey: @"CFBundleTypeExtensions"];
#else
	NSArray * myFileExtensions = [NSArray arrayWithObjects: @"of", @"fs", @"fth", @"4th", @"fo", @"fas", nil];
#endif
	
	NSString * fileExtension = [(NSString *)pathToFile pathExtension];
	NSEnumerator *extEnumerator = [myFileExtensions objectEnumerator];
	NSString * extObject;
	Boolean extensionOK = NO;
	while (extObject = [extEnumerator nextObject]) {
		if ([fileExtension isEqualToString:extObject]) {
			extensionOK = YES;
			break;
		}
	}
	
	if (!extensionOK)
		goto end;
	
	
	// setup for the file
	// NSLog(@"Forth Source File: %@", pathToFile);
	char *pathPtr = (char *)CFStringGetCStringPtr(pathToFile, kCFStringEncodingUTF8);
	// NSLog(@"pathPtr: %x", pathPtr);
	if (pathPtr == NULL) {
		if (CFStringGetCString(pathToFile, path, 2048, kCFStringEncodingUTF8)) {
			// NSLog(@"path: %s", path);
			syslog(LOG_ALERT, "ForthSpotlight: %s", path);
			fh = fopen(path, "r");
		}
	} else {
		// NSLog(@"pathPtr: %s", pathPtr);
		syslog(LOG_ALERT, "ForthSpotlight: %s", pathPtr);
		fh = fopen(pathPtr, "r");
	}
	if (!fh) 
		goto end;
	fclose(fh);
	NSStringEncoding fileEncoding;
	NSError *fileError = nil;
//	NSDictionary * fileAttributes;
//	NSURL * fileURL = [NSURL fileURLWithPath: (NSString *)pathToFile];
//	NSAttributedString * fileString = [[NSAttributedString alloc] initWithURL: fileURL options: NULL documentAttributes: &fileAttributes error: &fileError];
//	NSInteger errorCode = [fileError code];
//	NSString * errorDomain = [fileError domain];
	NSString * fileContent = [NSString stringWithContentsOfFile:(NSString *)pathToFile usedEncoding: &fileEncoding error: &fileError];
//	if (fileString) {
//		NSString * uti = [fileAttributes objectForKey: @"UTI"];
//		NSString * type = [fileAttributes objectForKey: @"DocumentType"];
//		fileEncoding = [[fileAttributes objectForKey: @"CharacterEncoding"] integerValue];
//	}
	if (!fileContent) 
		goto end;
	
	NSArray * fileLines = nil;
	if (fileContent) {
//		fileContent = [fileString string];
		fileContent = [fileContent stringByReplacingOccurrencesOfString: @"\r" withString: @"\n"];
		fileContent = [fileContent stringByReplacingOccurrencesOfString: @"\n\n" withString: @"\n"];
		fileLines = [fileContent componentsSeparatedByString: @"\n"];
	}
	
//	[fileString release];
	
	NSUInteger i, count = [fileLines count];
	for (i = 0; i < count; i++) {
		NSString * theString = [fileLines objectAtIndex:i];
		// syslog(LOG_ALERT, "Forth File: %s", line);
		
		range.location = 0;
		range.length = [theString length];
		
		// Look thu header lines to glean info
		// syslog(LOG_ALERT, "foundInitial = %d", foundInitial);
		// Look for 'File:` in the line
		theRange = [theString rangeOfString:@"File:\t" options: NSLiteralSearch range: range];
		// syslog(LOG_ALERT, "Forth File: theRange = %d %d", theRange.location, theRange.length);
		if (theRange.location != NSNotFound) {
			// found it, now split line at the ',`
			lineComponents = [theString componentsSeparatedByString:@",v "];
			if ([lineComponents count] == 2) {
				lineSubComponents = [lineComponents objectAtIndex: 1];
				lineComponents = [(NSString *)lineSubComponents componentsSeparatedByString:@" "];
				if ([lineComponents count]) {
					version = [lineComponents objectAtIndex: 0];
//					date = [lineComponents objectAtIndex: 1];
//					time = [lineComponents objectAtIndex: 2];
					author = [lineComponents objectAtIndex: 3];
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
					version = [version stringByTrimmingCharactersInSet: [NSCharacterSet whitespaceCharacterSet]];
					author = [author stringByTrimmingCharactersInSet: [NSCharacterSet whitespaceCharacterSet]];
				[(NSMutableDictionary *)attributes setObject:version
														  forKey:(NSString *)kMDItemVersion];
					// could walk the log and gather all authors but I don't see much point, will just take last checkin author
					[(NSMutableDictionary *)attributes setObject:author
														  forKey:(NSString *)kMDItemAuthors];
					// return YES so that the attributes are imported
					success=YES;
					foundTagLine=YES;
				}
			}
		}
		// Look for other data after the initial header line
		// For now, just the Contains: line
		theRange = [theString rangeOfString:@"Contains:" options: NSLiteralSearch range: range];
		if (theRange.location != NSNotFound) {
			// found it, now split line at Contains:
			theString = [theString stringByReplacingOccurrencesOfString: @"\t" withString: @" "];
			lineComponents = [theString componentsSeparatedByString:@"Contains:"];
			if ([lineComponents count]) {
				contains = [lineComponents objectAtIndex: 1];
				contains = [contains stringByTrimmingCharactersInSet: [NSCharacterSet whitespaceCharacterSet]];
				[(NSMutableDictionary *)attributes setObject:contains
													  forKey:(NSString *)kMDItemDescription];
				success=YES;
			}
		}
		// Now parse for definitions
		if (assertRegex(theString, @"^:\\s*(\\S+)\\s+.*") || 
			assertRegex(theString, @"^\\s*(code|CODE)\\s+(\\S+)\\s+.*") ||
			assertRegex(theString, @"^\\s*(tcode|TCODE)\\s+(\\S+)\\s+.*")) {
			theString = [theString stringByReplacingOccurrencesOfString: @"\t" withString: @" "];
			NSArray * lineComponents = [theString componentsSeparatedByString: @" "];
			NSString *definition = [lineComponents objectAtIndex: 1];
			definition = [definition stringByTrimmingCharactersInSet: [NSCharacterSet whitespaceCharacterSet]];
			[definitions addObject: definition];			
		}
		if (!foundTagLine) {
			theRange = [theString rangeOfString:@"Version:" options: NSLiteralSearch range: range];
			if (theRange.location != NSNotFound) {
				theString = [theString stringByReplacingOccurrencesOfString: @"\t" withString: @" "];
				NSArray * lineComponents = [theString componentsSeparatedByString: @" "];
				NSString *version = [lineComponents objectAtIndex: 1];
				version = [version stringByTrimmingCharactersInSet: [NSCharacterSet whitespaceCharacterSet]];
				[(NSMutableDictionary *)attributes setObject:version
													  forKey:(NSString *)kMDItemVersion];
				success=YES;
			}
			theRange = [theString rangeOfString:@"DRI:" options: NSLiteralSearch range: range];
			if (theRange.location != NSNotFound) {
				theString = [theString stringByReplacingOccurrencesOfString: @"\t" withString: @" "];
				NSArray * lineComponents = [theString componentsSeparatedByString: @"DRI:"];
				NSString *author = [lineComponents objectAtIndex: 1];
				author = [author stringByTrimmingCharactersInSet: [NSCharacterSet whitespaceCharacterSet]];
				[(NSMutableDictionary *)attributes setObject:author
													  forKey:(NSString *)kMDItemVersion];
				success=YES;
			}
			
		}		
		// accumulate line
		theString = [theString stringByReplacingOccurrencesOfString: @"\t" withString: @" "];
		[sourceContent appendString:theString];
	}
	// store definitions into metadata
	if ([definitions count] > 0) {
		[(NSMutableDictionary *)attributes setObject:definitions forKey:@"public.forth-source.definitions"];
//		int i;
//		for(i=0; i < [definitions count]; i++) {
//			NSLog(@"Def %d = %@", i, [definitions objectAtIndex: i]); 
//		}
		success=YES;
	}
	
	[(NSMutableDictionary *)attributes setObject:@"Forth Source File"
										  forKey:(NSString *)kMDItemKind];
	[(NSMutableDictionary *)attributes setObject:sourceContent forKey: (id)kMDItemTextContent];
//	[sourceContent release];
//	[definitions release];
	
end:
#ifndef TESTING
	[pool release];
#endif
	return success;
}
