#import <CoreFoundation/CoreFoundation.h>
#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>

Boolean processFile(NSString *path) {
	Boolean result;
	
	CFMutableDictionaryRef attributes = CFDictionaryCreateMutable(NULL,0,NULL,NULL);
	result = extract_forth(NULL, attributes, (CFStringRef)@"", (CFStringRef)path);
	if (attributes) 
		CFRelease(attributes);
	return result;
}

void processFolder(NSString * path) {
	BOOL isDir;
	NSString *file;
	NSFileManager * fileManager = [NSFileManager defaultManager];
	
	if ([fileManager fileExistsAtPath:path isDirectory:&isDir] && isDir) {
		NSDirectoryEnumerator *dirEnumerator = [fileManager enumeratorAtPath:path];
		while ((file = [dirEnumerator nextObject])) {
			file = [path stringByAppendingPathComponent:file];
			//NSLog(@"LibSpotlight testing: %@", file);
			processFolder(file);
		}
	} else
		processFile(path);
}

int main (int argc, const char * argv[]) {
    if (argc < 2)
        return -1;
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	NSString * path = [NSString stringWithUTF8String: (const char *)argv[1]];
	processFolder(path);
    [pool release];
	return 0;
}

