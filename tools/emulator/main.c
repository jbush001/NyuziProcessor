// 
// Copyright 2011-2015 Jeff Bush
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


#include <stdio.h>
#include <string.h>
#include <errno.h>
#include <sys/resource.h>
#include <getopt.h>
#include <stdlib.h>
#include "stats.h"
#include "core.h"
#include "device.h"
#include "cosimulation.h"
#include "fbwindow.h"

extern void remoteGdbMainLoop(Core *core, int enableFbWindow);

static void usage(void)
{
	fprintf(stderr, "usage: emulator [options] <hex image file>\n");
	fprintf(stderr, "options:\n");
	fprintf(stderr, "  -v Verbose, will print register transfer traces to stdout\n");
	fprintf(stderr, "  -m Mode, one of:\n");
	fprintf(stderr, "     normal  Run to completion (default)\n");
	fprintf(stderr, "     cosim   Cosimulation validation mode\n");
	fprintf(stderr, "     gdb     Start GDB listener on port 8000\n");
	fprintf(stderr, "  -f <width>x<height> Display framebuffer output in window\n");
	fprintf(stderr, "  -d <filename>,<start>,<length>  Dump memory\n");
	fprintf(stderr, "  -b <filename> Load file into a virtual block device\n");
	fprintf(stderr, "  -t <num> Total threads (default 4)\n");
	fprintf(stderr, "  -c <size> Total amount of memory (hex)\n");
}

int main(int argc, char *argv[])
{
	Core *core;
	int c;
	int enableMemoryDump = 0;
	uint32_t memDumpBase = 0;
	size_t memDumpLength = 0;
	char memDumpFilename[256];
	int verbose = 0;
	int fbWidth = 640;
	int fbHeight = 480;
	int blockDeviceOpen = 0;
	int enableFbWindow = 0;
	int totalThreads = 4;
	char *separator;
	size_t memorySize = 0x1000000;
	
	enum
	{
		kNormal,
		kCosimulation,
		kGdbRemoteDebug
	} mode = kNormal;

#if 0
	// Enable coredumps for this process
    struct rlimit limit;
	limit.rlim_cur = RLIM_INFINITY;
	limit.rlim_max = RLIM_INFINITY;
	setrlimit(RLIMIT_CORE, &limit);
#endif

	while ((c = getopt(argc, argv, "if:d:vm:b:t:c:")) != -1)
	{
		switch (c)
		{
			case 'v':
				verbose = 1;
				break;
				
			case 'f':
				enableFbWindow = 1;
				separator = strchr(optarg, 'x');
				if (!separator)
				{
					fprintf(stderr, "Invalid framebuffer size %s\n", optarg);
					return 1;
				}

				fbWidth = atoi(optarg);
				fbHeight = atoi(separator + 1);
				break;
				
			case 'm':
				if (strcmp(optarg, "normal") == 0)
					mode = kNormal;
				else if (strcmp(optarg, "cosim") == 0)
					mode = kCosimulation;
				else if (strcmp(optarg, "gdb") == 0)
					mode = kGdbRemoteDebug;
				else
				{
					fprintf(stderr, "Unkown execution mode %s\n", optarg);
					return 1;
				}

				break;
				
			case 'd':
				// Memory dump, of the form:
				//  filename,start,length
				separator = strchr(optarg, ',');
				if (separator == NULL)
				{
					fprintf(stderr, "bad format for memory dump\n");
					usage();
					return 1;
				}
				
				strncpy(memDumpFilename, optarg, separator - optarg);
				memDumpFilename[separator - optarg] = '\0';
				memDumpBase = strtol(separator + 1, NULL, 16);
	
				separator = strchr(separator + 1, ',');
				if (separator == NULL)
				{
					fprintf(stderr, "bad format for memory dump\n");
					usage();
					return 1;
				}
				
				memDumpLength = strtol(separator + 1, NULL, 16);
				enableMemoryDump = 1;
				break;
				
			case 'b':
				if (!openBlockDevice(optarg))
				{
					fprintf(stderr, "Couldn't open block device\n");
					return 1;
				}
				
				blockDeviceOpen = 1;
				break;
			
			case 'c':
				memorySize = strtol(optarg, NULL, 16);
				break;
				
			case 't':
				totalThreads = atoi(optarg);
				if (totalThreads < 1 || totalThreads > 32)
				{
					fprintf(stderr, "Total threads must be between 1 and 32\n");
					return 1;
				}
				
				break;
				
			case '?':
				usage();
				return 1;
		}
	}

	if (optind == argc)
	{
		fprintf(stderr, "No image filename specified\n");
		usage();
		return 1;
	}

	// We don't randomize memory for cosimulation mode, because 
	// memory is checked against the hardware model to ensure a match

	core = initCore(memorySize, totalThreads, mode != kCosimulation);
	
	if (loadHexFile(core, argv[optind]) < 0)
	{
		fprintf(stderr, "Error reading image %s\n", argv[optind]);
		return 1;
	}

	if (enableFbWindow)
		initFB(fbWidth, fbHeight);

	switch (mode)
	{
		case kNormal:
			if (verbose)
				enableTracing(core);
			
			setStopOnFault(core, 1);
			if (enableFbWindow)
			{
				while (executeInstructions(core, -1, 500000))
				{
					updateFB(getCoreFb(core));
					pollEvent();
				}
			}
			else
				executeInstructions(core, -1, 0x7fffffff);

			break;

		case kCosimulation:
			setStopOnFault(core, 0);
			if (!runCosim(core, verbose))
				return 1;	// Failed

			break;
			
		case kGdbRemoteDebug:
			setStopOnFault(core, 1);
			remoteGdbMainLoop(core, enableFbWindow);
			break;
	}

	if (enableMemoryDump)
		writeMemoryToFile(core, memDumpFilename, memDumpBase, memDumpLength);

	dumpInstructionStats();
	if (blockDeviceOpen)
		closeBlockDevice();
	
	return 0;
}
