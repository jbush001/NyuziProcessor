// 
// Copyright 2011-2012 Jeff Bush
// 
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
// 
//     http://www.apache.org/licenses/LICENSE-2.0
// 
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
// 

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
