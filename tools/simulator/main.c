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

// 
// Instruction Set Simulator
// This is instruction accurate, but not cycle accurate
//

#include <stdio.h>
#include <string.h>
#include <errno.h>
#include <sys/resource.h>
#include <getopt.h>
#include <stdlib.h>
#include "core.h"

void getBasename(char *outBasename, const char *filename)
{
	const char *c = filename + strlen(filename) - 1;
	while (c > filename)
	{
		if (*c == '.')
		{
			memcpy(outBasename, filename, c - filename);
			outBasename[c - filename] = '\0';
			return;
		}
	
		c--;
	}

	strcpy(outBasename, filename);
}

void runNonInteractive(Core *core)
{
	int i;

	enableTracing(core);
	for (i = 0; i < 40; i++)
	{
		if (!runQuantum(core))
			break;
	}
}

int main(int argc, const char *argv[])
{
	Core *core;
	char debugFilename[256];
	int interactive = 0;	// Interactive enables the debugger interface
	int c;
	const char *tok;
	int enableMemoryDump = 0;
	unsigned int memDumpBase;
	int memDumpLength;
	char memDumpFilename[256];
	int cosim = 0;
	int verbose = 0;

#if 0
	// Enable coredumps for this process
    struct rlimit limit;
	limit.rlim_cur = RLIM_INFINITY;
	limit.rlim_max = RLIM_INFINITY;
	setrlimit(RLIMIT_CORE, &limit);
#endif

	core = initCore();

	while ((c = getopt(argc, argv, "id:cv")) != -1)
	{
		switch (c)
		{
			case 'v':
				verbose = 1;
				break;
				
			case 'c':
				cosim = 1;
				break;
		
			case 'i':
				interactive = 1;
				break;
				
			case 'd':
				// Memory dump, of the form:
				//  filename,start,length
				tok = strchr(optarg, ',');
				if (tok == NULL)
				{
					fprintf(stderr, "bad format for memory dump\n");
					return 1;
				}
				
				strncpy(memDumpFilename, optarg, tok - optarg);
				memDumpFilename[tok - optarg] = '\0';
				memDumpBase = strtol(tok + 1, NULL, 16);
	
				tok = strchr(tok + 1, ',');
				if (tok == NULL)
				{
					fprintf(stderr, "bad format for memory dump\n");
					return 1;
				}
				
				memDumpLength = strtol(tok + 1, NULL, 16);
				enableMemoryDump = 1;
				break;
		}
	}

	if (optind == argc)
	{
		fprintf(stderr, "need to enter an image filename\n");
		return 1;
	}
	
	if (loadHexFile(core, argv[optind]) < 0)
	{
		fprintf(stderr, "*error reading image %s %s\n", argv[1], strerror(errno));
		return 1;
	}

	if (cosim)
	{
		if (!runCosim(core, verbose))
			return 1;	// Failed
	}
	else if (interactive)
	{
		getBasename(debugFilename, argv[1]);
		strcat(debugFilename, ".dbg");
		if (readDebugInfoFile() < 0)
		{
			fprintf(stderr, "*error reading debug info file\n");
			return 1;
		}
	
		commandInterfaceReadLoop(core);
	}
	else
	{
		if (verbose)
			enableTracing(core);
			
		runNonInteractive(core);
	}

	if (enableMemoryDump)
		writeMemoryToFile(core, memDumpFilename, memDumpBase, memDumpLength);
	
	return 0;
}
