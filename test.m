#include "test.h"
//#include <MorefilesX.h>

Boolean processfile(const char *path) {
	CFStringRef thePath;
	Boolean result;
	
	CFMutableDictionaryRef attributes = CFDictionaryCreateMutable(NULL,0,NULL,NULL);
	thePath = CFStringCreateWithCString(NULL,path,kCFStringEncodingMacRoman);
	if (CFStringHasSuffix(thePath, (CFStringRef)@".of")) {
		// NSLog(@"File: %@", thePath);
		result = GetMetadataForFile(NULL, attributes, (CFStringRef)@"", thePath);
	}
	if (attributes) CFRelease(attributes);
	return result;
}

int main (int argc, const char * argv[]) {
	char filepath[256];
	FSSpec spec;
	ItemCount numRefs;
	Boolean containerChanged, isDir;
	OSStatus sts;
	OSErr err;
	FSRef *container = nil, ref, *refPtr;
	FSRef **refsHandle;
	
	
	sts = FSPathMakeRef((const UInt8 *)argv[1],&ref,&isDir);
	if (isDir) {
		container = (FSRef *)NewPtr(sizeof(container));
		sts = FSMakeFSRef(spec.vRefNum, spec.parID, spec.name, container);
		refPtr = (FSRef *)&refsHandle;
		err = FSGetDirectoryItems(&ref, refPtr, &numRefs, &containerChanged);
		if (!err) {
			int i;
			refPtr = *refsHandle;
			for(i=0; i<numRefs; i++) {
				ref = refPtr[i];
				sts = FSRefMakePath(&ref, (UInt8 *)&filepath,256);
				if (!sts) 
					processfile(filepath);
			}
			DisposeHandle((Handle)refsHandle);
			err = MemError();
		}
		DisposePtr((Ptr)container);
	} else
		processfile(argv[1]);
	return 0;
}

