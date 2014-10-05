// 
// Copyright (C) 2011-2014 Jeff Bush
// 
// This program is free software; you can redistribute it and/or
// modify it under the terms of the GNU General Public License
// as published by the Free Software Foundation; either version 2
// of the License, or (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program; if not, write to the Free Software
// Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
// 



// 
// Instruction Set Simulator
//

#include <stdio.h>
#include <string.h>
#include <errno.h>
#include <sys/resource.h>
#include <getopt.h>
#include <stdlib.h>
#include "core.h"

void runNonInteractive(Core *core)
{
	int i;

	for (i = 0; i < 80000; i++)
	{
		if (!runQuantum(core, 1000))
			break;
	}
}

void runUI();

int main(int argc, const char *argv[])
{
	Core *core;
	char debugFilename[256];
	int c;
	const char *tok;
	int enableMemoryDump = 0;
	unsigned int memDumpBase;
	int memDumpLength;
	char memDumpFilename[256];
	int verbose = 0;
	int fbWidth = 640;
	int fbHeight = 480;
	enum
	{
		kNormal,
		kCosimulation,
		kGui,
		kDebug,
		kGdbRemoteDebug
	} mode = kNormal;

#if 0
	// Enable coredumps for this process
    struct rlimit limit;
	limit.rlim_cur = RLIM_INFINITY;
	limit.rlim_max = RLIM_INFINITY;
	setrlimit(RLIMIT_CORE, &limit);
#endif

	core = initCore(0x1000000);

	while ((c = getopt(argc, argv, "id:vm:w:h:")) != -1)
	{
		switch (c)
		{
			case 'v':
				verbose = 1;
				break;
				
			case 'm':
				if (strcmp(optarg, "cosim") == 0)
					mode = kCosimulation;
#if ENABLE_COCOA
				else if (strcmp(optarg, "gui") == 0)
					mode = kGui;
#endif
				else if (strcmp(optarg, "debug") == 0)
					mode = kDebug;
				else if (strcmp(optarg, "gdb") == 0)
					mode = kGdbRemoteDebug;
				else
				{
					fprintf(stderr, "Unkown execution mode %s\n", optarg);
					return 1;
				}
					
				break;
				
			case 'w':
				fbWidth = atoi(optarg);
				break;
				
			case 'h':
				fbHeight = atoi(optarg);
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

	switch (mode)
	{
		case kNormal:
			if (verbose)
				enableTracing(core);
			
			runNonInteractive(core);
			break;

		case kCosimulation:
			if (!runCosim(core, verbose))
				return 1;	// Failed

			break;

		case kGui:
#if ENABLE_COCOA
			runUI(core, fbWidth, fbHeight);
#endif
			break;

		case kDebug:
			commandInterfaceReadLoop(core);
			break;
			
		case kGdbRemoteDebug:
			remoteGdbMainLoop(core);
			break;
	}

	if (enableMemoryDump)
		writeMemoryToFile(core, memDumpFilename, memDumpBase, memDumpLength);
	
	printf("%d total instructions executed\n", getTotalInstructionCount(core));
	
	return 0;
}
