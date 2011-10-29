#ifndef __DEBUG_INFO_H
#define __DEBUG_INFO_H

int readDebugInfoFile(const char *path);

void getCurrentFunction(int pc,char *outName, int length);
int getSourceLocationForAddress(unsigned int pc, const char **outFile, int *outLine);

// @returns
//   0xffffffff - no PC found at this location
// @param outActualLine - if the actual line with executable code is below
//    this one, returned here.  If this is NULL, it is ignored.
unsigned int getAddressForSourceLocation(const char *filename, int linenum, int *outActualLine);

#endif
