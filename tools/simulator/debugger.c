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
// Command interface for Eclipse debugger plugin
//

#include <stdio.h>
#include <string.h>
#include <unistd.h>
#include <stdlib.h>
#include <sys/poll.h>
#include <stdarg.h>
#include "core.h"

#define INPUT_BUFFER_SIZE 256
#define MAX_TOKENS 64

typedef void (*CommandDispatchFunction)(const char *options[], int optionCount);

static Core *gCore;
static int gIsRunning = 0;
static char inputBuffer[INPUT_BUFFER_SIZE];
static int inputBufferLength;
static int lastScalarRegisterValue[NUM_REGISTERS];
static int lastVectorRegisterValue[NUM_REGISTERS][16];

void sendResponse(const char *format, ...)
{
	va_list args;

	va_start(args, format);
	vprintf(format, args);
	va_end(args);
}

void responseComplete()
{
	printf("\n");
	fflush(stdout);
}

// Print for any case where execution is suspended, including suspend or
// stepping.
// Arguments will be: <file> <lineno> [<reg> <value>...]
void printSuspendResponse()
{
	int i;
	int lane;
	const char *file;
	int line;
	int pc = getPc(gCore);
	
	// Scalar registers
	for (i = 0; i < NUM_REGISTERS; i++)
	{
		int currentValue = getScalarRegister(gCore, i);
		if (currentValue != lastScalarRegisterValue[i])
		{
			lastScalarRegisterValue[i] = currentValue;
			sendResponse("r%d %08x ", i, currentValue);
		}
	}

	// Vector registers
	for (i = 0; i < NUM_REGISTERS; i++)
	{
		int dirty = 0;
		for (lane = 0; lane < 16; lane++)
		{
			int currentValue = getVectorRegister(gCore, i, lane);
			if (currentValue != lastVectorRegisterValue[i][lane])
			{
				lastVectorRegisterValue[i][lane] = currentValue;
				dirty = 1;
			}
		}
	
		if (dirty)
		{
			sendResponse("v%d ", i);
			for (lane = 0; lane < 16; lane++)
				sendResponse("%08x", lastVectorRegisterValue[i][lane]);

			sendResponse(" ");
		}
	}
	
	responseComplete();
}

void doResume(const char *options[], int optionCount)
{
	gIsRunning = 1;
	sendResponse("running");
	responseComplete();
}

void doSuspend(const char *options[], int optionCount)
{
	gIsRunning = 0;
	printSuspendResponse();
}

void doStepInto(const char *options[], int optionCount)
{
	stepInto(gCore);
	printSuspendResponse();
}

void doStepOver(const char *options[], int optionCount)
{
	stepOver(gCore);
	printSuspendResponse();
}

void doStepReturn(const char *options[], int optionCount)
{
	stepReturn(gCore);
	printSuspendResponse();
}

void doSetBreakpoint(const char *options[], int optionCount)
{
	int pc;

	pc = atoi(options[1]);
	if (pc == 0xffffffff)
		sendResponse("error");
	else
		setBreakpoint(gCore, pc);
	
	responseComplete();
}

void doDeleteBreakpoint(const char *options[], int optionCount)
{
	int pc;
	
	pc = atoi(options[0]);
	if (pc == 0xffffffff)
		sendResponse("error");
	else
	{
		clearBreakpoint(gCore, pc);
		sendResponse("deleted");
	}
	
	responseComplete();
}

void doReadMemory(const char *options[], int optionCount)
{
	int startAddress = atoi(options[0]);
	int length = atoi(options[1]);
	int i;
	
	for (i = 0; i < length; i++)
		sendResponse("%02x ", readMemoryByte(gCore, startAddress + i));

	responseComplete();
}

static struct 
{
	const char *name;
	CommandDispatchFunction function;
} commandTable[] = {
	{ "step-into", doStepInto },
	{ "step-over", doStepOver },
	{ "step-return", doStepReturn },
	{ "suspend", doSuspend },
	{ "resume", doResume },
	{ "delete-breakpoint", doDeleteBreakpoint },
	{ "set-breakpoint", doSetBreakpoint },
	{ "read-memory", doReadMemory },
	{ NULL, NULL }
};

CommandDispatchFunction lookupCommand(const char *name)
{
	int i;
	
	for (i = 0; commandTable[i].name != NULL; i++)
	{
		if (strcmp(name, commandTable[i].name) == 0)
			return commandTable[i].function;
	}
	
	return NULL;
}

void processLine(char *line, int count)
{
	char *c;
	const char *tokens[MAX_TOKENS];
	int tokenCount = 1;
	CommandDispatchFunction func;
	const char *cmd;

	line[count] = '\0';

	cmd = line;
	c = line;	
	while (*c != '\0')
	{
		if (*c == '\n' || *c == ' ' || *c == '\r')
		{
			*c = '\0';
			tokens[tokenCount++] = c + 1;			
		}
		
		c++;
	}

	// The last token will always be empty, so dump that now
	tokenCount--;

	func = lookupCommand(cmd);
	if (func == NULL)
	{
		sendResponse("unknown-command %s", cmd);
		responseComplete();
	}
	else
		(*func)(&tokens[1], tokenCount - 1);

}

void readStdin()
{
	int got;
	int i;
	int inOffset = 0;
	int sliceLength;

	got = read(0, inputBuffer + inputBufferLength, INPUT_BUFFER_SIZE - 
		inputBufferLength);

	fflush(stdout);
	if (got < 0)
		exit(1);

	// Scan to see if there is a newline
	for (i = inputBufferLength; i < inputBufferLength + got; i++)
	{
		if (inputBuffer[i] == '\n')
		{
			processLine(inputBuffer + inOffset, i - inOffset);
			inOffset = i + 1;
		}
	}

	sliceLength = inputBufferLength + got - inOffset;
	memcpy(inputBuffer, inputBuffer + inOffset, sliceLength);
	inputBufferLength = sliceLength;
}

// Receive commands from the GDB controller
void commandInterfaceReadLoop(Core *core)
{
	gCore = core;

	// Notify the debugger that we are initialized.
	sendResponse("!started ");
	printSuspendResponse();

	for (;;)
	{
		if (gIsRunning)
		{
			struct pollfd pfd = { 0, POLLIN, 0 };
			int numReady = poll(&pfd, 1, 0);
			if (numReady > 0)
				readStdin();
			else
			{
				if (runQuantum(gCore, 1000) == 0)
				{
					// Hit a breakpoint
					gIsRunning = 0;
					sendResponse("!breakpoint-hit ");
					printSuspendResponse();
				}
			}
		}
		else
			readStdin();
	}
}
