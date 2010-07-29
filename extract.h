/*
 *  GetMetadataForFile.h
 *  Forth Spotlighter
 *
 *  Created by Dave on 5/10/05.
 *  Copyright 2005 __MyCompanyName__. All rights reserved.
 *
 */

#ifndef __GetMetadataForFile__
#define __GetMetadataForFile__

Boolean GetMetadataForFile(void* thisInterface, 
						   CFMutableDictionaryRef attributes, 
						   CFStringRef contentTypeUTI,
						   CFStringRef pathToFile);

#endif
