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

#include <arpa/inet.h>
#include <assert.h>
#include <errno.h>
#include <netinet/in.h>
#include <stdarg.h>
#include <stdio.h>
#include <string.h>
#include <sys/socket.h>
#include <sys/types.h>
#include <unistd.h>
#include <stdlib.h>
#include "core.h"
#include "fbwindow.h"
#include "util.h"

#define TRAP_SIGNAL 5 // SIGTRAP

extern void remoteGdbMainLoop(Core *core, int enableFbWindow);
static void sendFormattedResponse(const char *format, ...)  __attribute__ ((format (printf, 1, 2)));

static Core *gCore;
static int gClientSocket = -1;
static int *gLastSignal;

static int readByte(void)
{
	unsigned char ch;
	if (read(gClientSocket, &ch, 1) < 1)
	{
		perror("error reading from debug socket");
		return -1;
	}
	
	return ch;
}

static int readPacket(char *request, int maxLength)
{
	int ch;
	int packetLen;

	// Wait for packet start
	do
	{
		ch = readByte();
		if (ch < 0)
			return -1;
	}
	while (ch != '$');

	// Read body
	packetLen = 0;
	while (true)
	{
		ch = readByte();
		if (ch < 0)
			return -1;
		
		if (ch == '#')
			break;
		
		if (packetLen < maxLength)
			request[packetLen++] = (char) ch;
	}
	
	// Read checksum and discard
	readByte();
	readByte();
	
	request[packetLen] = '\0';
	return packetLen;
}

static const char *kGenericRegs[] = {
	"fp",
	"sp",
	"ra",
	"pc"
};

static void sendResponsePacket(const char *request)
{
	unsigned char checksum;
	char checksumChars[16];
	int i;
	size_t requestLength = strlen(request);
	
	if (write(gClientSocket, "$", 1) < 1
		|| write(gClientSocket, request, requestLength) < (ssize_t) requestLength
		|| write(gClientSocket, "#", 1) < 1)
	{
		perror("Error writing to debugger socket");
		exit(1);
	}

	checksum = 0;
	for (i = 0; request[i]; i++)
		checksum += request[i];
	
	sprintf(checksumChars, "%02x", checksum);
	if (write(gClientSocket, checksumChars, 2) < 2)
	{
		perror("Error writing to debugger socket");
		exit(1);
	}
}

static void sendFormattedResponse(const char *format, ...)
{
	char buf[256];
	va_list args;
	va_start(args, format);
	vsnprintf(buf, sizeof(buf) - 1, format, args);
	va_end(args);
	sendResponsePacket(buf);
}

// threadId of ALL_THREADS means run all threads.  Otherwise, run just the 
// indicated thread.
static void runUntilInterrupt(Core *core, uint32_t threadId, bool enableFbWindow)
{
	fd_set readFds;
	int result;
	struct timeval timeout; 

	FD_ZERO(&readFds);

	while (1)
	{
		if (!executeInstructions(core, threadId, gScreenRefreshRate))
			break;

		if (enableFbWindow)
		{
			updateFramebuffer(getFramebuffer(core));
			pollEvent();
		}

		FD_SET(gClientSocket, &readFds);
		timeout.tv_sec = 0;
		timeout.tv_usec = 0;
		result = select(gClientSocket + 1, &readFds, NULL, NULL, &timeout);
		if ((result < 0 && errno != EINTR) || result == 1)
			break;
	}
}

static unsigned char decodeHexByte(const char *ptr)
{
	int i;
	int retval = 0;

	for (i = 0; i < 2; i++)
	{
		if (ptr[i] >= '0' && ptr[i] <= '9')
			retval = (retval << 4) | (ptr[i] - '0');
		else if (ptr[i] >= 'a' && ptr[i] <= 'f')
			retval = (retval << 4) | (ptr[i] - 'a' + 10);
		else if (ptr[i] >= 'A' && ptr[i] <= 'F')
			retval = (retval << 4) | (ptr[i] - 'A' + 10);
		else
			assert(0);	// Bad character
	}
	
	return (unsigned char) retval;
}

void remoteGdbMainLoop(Core *core, int enableFbWindow)
{
	int listenSocket;
	struct sockaddr_in address;
	socklen_t addressLength;
	int got;
	char request[256];
	uint32_t i;
	bool noAckMode = false;
	int optval;
	char response[256];
	uint32_t currentThread = 0;
	
	gCore = core;
	gLastSignal = calloc(sizeof(int), getTotalThreads(core));
	for (i = 0; i < getTotalThreads(core); i++)
		gLastSignal[i] = 0;

	listenSocket = socket(PF_INET, SOCK_STREAM, 0);
	if (listenSocket < 0)
	{
		perror("error setting up debug socket (socket)");
		return;
	}

	optval = 1;
	if (setsockopt(listenSocket, SOL_SOCKET, SO_REUSEADDR, &optval, sizeof(optval)) < 0)
	{
		perror("error setting up debug socket (setsockopt)");
		return;
	}
	
	address.sin_family = AF_INET;
	address.sin_port = htons(8000);
	address.sin_addr.s_addr = htonl(INADDR_ANY);
	if (bind(listenSocket, (struct sockaddr*) &address, sizeof(address)) < 0)
	{	
		perror("error setting up debug socket (bind)");
		return;
	}

	if (listen(listenSocket, 1) < 0)
	{
		perror("error setting up debug socket (listen)");
		return;
	}
	
	while (true)
	{
		// Wait for a new client socket
		while (true)
		{
			addressLength = sizeof(address);
			gClientSocket = accept(listenSocket, (struct sockaddr*) &address,
				&addressLength);
			if (gClientSocket >= 0)
				break;
		}
		
		noAckMode = false;

		// Process commands
		while (true)
		{
			got = readPacket(request, sizeof(request));
			if (got < 0) 
				break;
			
			if (!noAckMode)
			{
				if (write(gClientSocket, "+", 1) != 1)
				{
					perror("Error writing to debug socket");
					exit(1);
				}
			}

			switch (request[0])
			{
				// Set arguments
				case 'A':
					// We don't support setting program arguments, so just silently ignore.
					sendResponsePacket("OK");
					break;

				// Continue
				case 'c':
				case 'C':
					runUntilInterrupt(core, ALL_THREADS, enableFbWindow);
					gLastSignal[currentThread] = TRAP_SIGNAL;
					sendFormattedResponse("S%02x", gLastSignal[currentThread]);
					break;

				// Pick thread
				case 'H':
					if (request[1] == 'g' || request[1] == 'c')
					{
						// XXX hack: the request type controls which operations this
						// applies for.
						currentThread = (uint32_t)(request[2] - '1');
						sendResponsePacket("OK");
					}
					else
						sendResponsePacket("");

					break;
					
				// Kill 
				case 'k':
					return;

				// Read/write memory
				case 'm':
				case 'M':
				{
					char *lenPtr;
					char *dataPtr;
					unsigned int start;
					unsigned int length;
					unsigned int offset;
					
					start = (uint32_t) strtoul(request + 1, &lenPtr, 16);
					length = (uint32_t) strtoul(lenPtr + 1, &dataPtr, 16);
					if (request[0] == 'm')
					{
						// Read memory
						for (offset = 0; offset < length; offset++)
							sprintf(response + offset * 2, "%02x", readMemoryByte(core, start + offset));
					
						sendResponsePacket(response);
					}
					else
					{
						// Write memory
						dataPtr += 1;	// Skip colon
						for (offset = 0; offset < length; offset++)
							writeMemoryByte(core, start + offset, decodeHexByte(dataPtr + offset * 2));

						sendResponsePacket("OK");
					}
					
					break;
				}

				// Read register
				case 'p':
				case 'g':
				{
					uint32_t regId = (uint32_t) strtoul(request + 1, NULL, 16);
					uint32_t value;
					if (regId < 32)
					{
						value = getScalarRegister(core, currentThread, regId);
						sendFormattedResponse("%08x", endianSwap32(value));
					}
					else if (regId < 64)
					{
						uint32_t lane;
						
						for (lane = 0; lane < 16; lane++)
						{
							value = getVectorRegister(core, currentThread, regId, lane);
							sprintf(response + lane * 8, "%08x", endianSwap32(value));
						}

						sendResponsePacket(response);
					}
					else
						sendResponsePacket("");
				
					break;
				}
				
				// XXX need to implement write register
									
				// Query
				case 'q':
					if (strcmp(request + 1, "LaunchSuccess") == 0)
						sendResponsePacket("OK");
					else if (strcmp(request + 1, "HostInfo") == 0)
						sendResponsePacket("triple:nyuzi;endian:little;ptrsize:4");
					else if (strcmp(request + 1, "ProcessInfo") == 0)
						sendResponsePacket("pid:1");
					else if (strcmp(request + 1, "fThreadInfo") == 0)
						sendResponsePacket("m1,2,3,4");	// XXX need to query number of threads
					else if (strcmp(request + 1, "sThreadInfo") == 0)
						sendResponsePacket("l");
					else if (memcmp(request + 1, "ThreadStopInfo", 14) == 0)
						sprintf(response, "S%02x", gLastSignal[currentThread]);
					else if (memcmp(request + 1, "RegisterInfo", 12) == 0)
					{
						uint32_t regId = (uint32_t) strtoul(request + 13, NULL, 16);
						if (regId < 32)
						{
							sprintf(response, "name:s%d;bitsize:32;encoding:uint;format:hex;set:General Purpose Scalar Registers;gcc:%d;dwarf:%d;",
								regId, regId, regId);
								
							if (regId >= 28)
								sprintf(response + strlen(response), "generic:%s;", kGenericRegs[regId - 28]);
						}
						else if (regId < 64)
						{
							sprintf(response, "name:v%d;bitsize:512;encoding:uint;format:vector-uint32;set:General Purpose Vector Registers;gcc:%d;dwarf:%d;",
								regId - 32, regId, regId);
						}
						else
							strcpy(response, "");
						
						sendResponsePacket(response);
					}
					else if (strcmp(request + 1, "C") == 0)
						sendFormattedResponse("QC%02x", currentThread + 1);
					else
						sendResponsePacket("");	// Not supported
					
					break;

				// Set Value
				case 'Q':
					if (strcmp(request + 1, "StartNoAckMode") == 0)
					{
						noAckMode = true;
						sendResponsePacket("OK");
					}
					else
						sendResponsePacket("");	// Not supported
					
					break;
					
				// Single step
				case 's':
				case 'S':
					singleStep(core, currentThread);
					gLastSignal[currentThread] = TRAP_SIGNAL;
					sendFormattedResponse("S%02x", gLastSignal[currentThread]);
					break;
					
				// Multi-character command
				case 'v':
					if (strcmp(request, "vCont?") == 0)
						sendResponsePacket("vCont;C;c;S;s");
					else if (memcmp(request, "vCont;", 6) == 0)
					{
						// XXX hack.  There are two things lldb requests.  One is
						// to step one thread while resuming the others.  In this case,
						// I cheat and only step the one.  The other is just to continue,
						// which I perform in the else clause.
						const char *sreq = strchr(request, 's');
						if (sreq != NULL)
						{
							// s:0001
							currentThread = (uint32_t) strtoul(sreq + 2, NULL, 16) - 1;
							singleStep(core, currentThread);
							gLastSignal[currentThread] = TRAP_SIGNAL;
							sendFormattedResponse("S%02x", gLastSignal[currentThread]);
						}
						else
						{
							runUntilInterrupt(core, ALL_THREADS, enableFbWindow);
							gLastSignal[currentThread] = TRAP_SIGNAL;
							sendFormattedResponse("S%02x", gLastSignal[currentThread]);
						}
					}
					else
						sendResponsePacket("");
					
					break;
					
				// Clear breakpoint
				case 'z':
					if (clearBreakpoint(core, (uint32_t) strtoul(request + 3, NULL, 16)) < 0)
						sendResponsePacket(""); // Error
					else
						sendResponsePacket("OK");

					break;
					
				// Set breakpoint
				case 'Z':
					if (setBreakpoint(core, (uint32_t) strtoul(request + 3, NULL, 16)) < 0)
						sendResponsePacket(""); // Error
					else
						sendResponsePacket("OK");

					break;
					
				// Get last signal
				case '?':
					sprintf(response, "S%02x", gLastSignal[currentThread]);
					sendResponsePacket(response);
					break;
					
				// Unknown, return error
				default:
					sendResponsePacket("");
			}
		}

		close(gClientSocket);
	}
}

