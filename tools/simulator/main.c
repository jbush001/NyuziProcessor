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
// It is used in three different ways:
//
// 1. If invoked with -c, it runs in co-simulation mode.  It reads instruction
//    side effects from stdin (which are produced by the Verilog model) and 
//    verifies they are correct given the program.
// 2. By default, it runs in non-interactive mode, where it simply runs the program
//    and (generally) dumps memory when it is done.  This can be used to debug
//    programs.
// 3. Non-interactive mode also exposes a virtual console (address 0xFFFF0004)
//    which writes to stdout.  This is used in the whole-program compiler validation
//    tests. 
// 4. If run in 'interactive' mode with -i, it runs as a debugger.  It takes
//    commands from stdin that allow stepping the program and inspecting state.
//    Note that the eclipse plugin in tools/ is designed to work with this mode.
//    This is a bit out of date and currently doesn't support multiple strands.
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

	for (i = 0; i < 80000; i++)
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

	core = initCore(0x500000);

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
		fprintf(stderr, "*error reading image %s\n", argv[optind]);
		return 1;
	}

	if (cosim)
	{
		// Co-simulation
		if (!runCosim(core, verbose))
			return 1;	// Failed
	}
	else if (interactive)
		commandInterfaceReadLoop(core);
	else
	{
		// Run in non-interactive mode
		if (verbose)
			enableTracing(core);
			
		runNonInteractive(core);
	}

	if (enableMemoryDump)
		writeMemoryToFile(core, memDumpFilename, memDumpBase, memDumpLength);
	
	printf("%d total instructions executed\n", getTotalInstructionCount(core));
	
	return 0;
}
