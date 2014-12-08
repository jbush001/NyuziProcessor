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

extern void runUI(Core *core, int fbWidth, int fbHeight);
extern void commandInterfaceReadLoop(Core *core);
extern void remoteGdbMainLoop(Core *core);

void runNonInteractive(Core *core)
{
	while (runQuantum(core, -1, 1000))
		;
}

void usage()
{
	fprintf(stderr, "usage: simulator [options] <hex image file>\n");
	fprintf(stderr, "options:\n");
	fprintf(stderr, "  -v   Verbose, will print register transfer traces to stdout\n");
	fprintf(stderr, "  -m   Mode, one of:\n");
	fprintf(stderr, "        cosim   Cosimulation validation mode\n");
#if ENABLE_COCOA
	fprintf(stderr, "        gui     Display framebuffer output in window\n");
#endif
	fprintf(stderr, "        gdb     Start GDB listener on port 8000\n");
	fprintf(stderr, "  -w   Width of framebuffer for GUI mode\n");
	fprintf(stderr, "  -h   Height of framebuffer for GUI mode\n");
	fprintf(stderr, "  -d   Dump memory filename,start,length\n");
	fprintf(stderr, "  -b   Load file into a virtual block device\n");
}

int main(int argc, char *argv[])
{
	Core *core;
	int c;
	const char *tok;
	int enableMemoryDump = 0;
	unsigned int memDumpBase;
	int memDumpLength;
	char memDumpFilename[256];
	int verbose = 0;
	int fbWidth = 640;
	int fbHeight = 480;
	int blockDeviceOpen = 0;
	enum
	{
		kNormal,
		kCosimulation,
		kGui,
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

	while ((c = getopt(argc, argv, "id:vm:w:h:b:")) != -1)
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
					usage();
					return 1;
				}
				
				strncpy(memDumpFilename, optarg, tok - optarg);
				memDumpFilename[tok - optarg] = '\0';
				memDumpBase = strtol(tok + 1, NULL, 16);
	
				tok = strchr(tok + 1, ',');
				if (tok == NULL)
				{
					fprintf(stderr, "bad format for memory dump\n");
					usage();
					return 1;
				}
				
				memDumpLength = strtol(tok + 1, NULL, 16);
				enableMemoryDump = 1;
				break;
				
			case 'b':
				if (!openBlockDevice(optarg))
				{
					fprintf(stderr, "Couldn't open block device");
					return 1;
				}
				
				blockDeviceOpen = 1;
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
	
	if (loadHexFile(core, argv[optind]) < 0)
	{
		fprintf(stderr, "Error reading image %s\n", argv[optind]);
		return 1;
	}

	switch (mode)
	{
		case kNormal:
			if (verbose)
				enableTracing(core);
			
			setStopOnFault(core, 1);
			runNonInteractive(core);
			break;

		case kCosimulation:
			setStopOnFault(core, 0);
			if (!runCosim(core, verbose))
				return 1;	// Failed

			break;

		case kGui:
#if ENABLE_COCOA
			runUI(core, fbWidth, fbHeight);
#endif
			break;
			
		case kGdbRemoteDebug:
			setStopOnFault(core, 1);
			remoteGdbMainLoop(core);
			break;
	}

	if (enableMemoryDump)
		writeMemoryToFile(core, memDumpFilename, memDumpBase, memDumpLength);

	dumpInstructionStats();
	if (blockDeviceOpen)
		closeBlockDevice();
	
	return 0;
}
