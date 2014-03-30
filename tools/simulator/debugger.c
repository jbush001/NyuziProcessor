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
// Interactive command line debugger.
//

#include <ctype.h>
#include <stdio.h>
#include <string.h>
#include <unistd.h>
#include <stdlib.h>
#include <sys/signal.h>
#include <sys/poll.h>
#include <stdarg.h>
#include <readline/readline.h>
#include "core.h"

#define MAX_TOKENS 64

typedef void (*CommandDispatchFunction)(const char *options[], int optionCount);

static Core *gCore;
static int gIsRunning = 0;

static int parseNumber(const char *num, unsigned int *outValue)
{
	const char *digit;
	unsigned int value = 0;

	if (num[0] == '0' && num[1] == 'x')
	{
		// Hexadecimal value
		digit = num + 2;
		while (*digit)
		{
			if (*digit >= '0' && *digit <= '9')
				value = (value * 16) + *digit - '0';
			else if (*digit >= 'A' && *digit <= 'F')
				value = (value * 16) + *digit - 'A' + 10;
			else if (*digit >= 'a' && *digit <= 'f')
				value = (value * 16) + *digit - 'a' + 10;
			else
				return 0;
			
			digit++;
		}
		
		*outValue = value;
		return 1;
	}
	else
	{
		// Decimal value
		digit = num;
		while (*digit)
		{
			if (*digit >= '0' && *digit <= '9')
				value = (value * 10) + *digit - '0';
			else
				return 0;
			
			digit++;
		}
		
		*outValue = value;
		return 1;
	}
}

static void sendResponse(const char *format, ...)
{
	va_list args;

	va_start(args, format);
	vprintf(format, args);
	va_end(args);
	fflush(stdout);
}

static void doRegs(const char *options[], int optionCount)
{
	int i;
	int lane;
	
	sendResponse("strand %d\n", getCurrentStrand(gCore));
	
	// Scalar registers
	for (i = 0; i < NUM_REGISTERS; i++)
	{
		sendResponse("r%d %08x ", i, getScalarRegister(gCore, i));
		if (i % 4 == 3)
			sendResponse("\n");
	}

	// Vector registers
	for (i = 0; i < NUM_REGISTERS; i++)
	{
		sendResponse("v%d ", i);
		for (lane = 0; lane < 16; lane++)
			sendResponse("%08x", getVectorRegister(gCore, i, lane));

		sendResponse("\n");
	}
}

static void handleControlC(int val)
{
	gIsRunning = 0;
}

static void doResume(const char *options[], int optionCount)
{
	gIsRunning = 1;
	sendResponse("Running...");
	while (gIsRunning)
	{
		if (runQuantum(gCore, 1000) == 0)
		{
			// Hit a breakpoint
			gIsRunning = 0;
			sendResponse("strand %d pc %08x\n", getCurrentStrand(gCore), getPc(gCore));
		}
	}
	
	sendResponse("stopped\n");
}

static void doQuit(const char *options[], int optionCount)
{
	sendResponse("Quitting...\n");
	exit(1);
}

static void doSingleStep(const char *options[], int optionCount)
{
	singleStep(gCore);
}

static void doSetBreakpoint(const char *options[], int optionCount)
{
	unsigned int pc;

	if (optionCount != 1)
	{
		sendResponse("need address (decimal) %d\n", optionCount);
		return;
	}

	if (!parseNumber(options[0], &pc))
		sendResponse("Invalid program counter value");
	else
		setBreakpoint(gCore, pc);
}

static void doDeleteBreakpoint(const char *options[], int optionCount)
{
	unsigned int pc;

	if (optionCount != 1)
	{
		sendResponse("need address (decimal) %d\n", optionCount);
		return;
	}
	
	if (!parseNumber(options[0], &pc))
		sendResponse("Invalid program counter value");
	else
	{
		clearBreakpoint(gCore, pc);
		sendResponse("deleted");
	}
}

#define LINE_LENGTH 16

static void doReadMemory(const char *options[], int optionCount)
{
	unsigned int startAddress, length;
	unsigned int lineStartOffset = 0;
	unsigned int lineOffset;
	
	if (!parseNumber(options[0], &startAddress) || !parseNumber(options[1], &length))
		sendResponse("Invalid address or length");
	else
	{
		while (lineStartOffset < length)
		{
			sendResponse("%08x    ", startAddress + lineStartOffset);
			
			for (lineOffset = 0; lineOffset < LINE_LENGTH; lineOffset++)
			{
				sendResponse("%02x ", readMemoryByte(gCore, startAddress + lineStartOffset
					+ lineOffset));
			}
			
			sendResponse("    ");
			for (lineOffset = 0; lineOffset < LINE_LENGTH; lineOffset++)
			{
				int ch = readMemoryByte(gCore, startAddress + lineStartOffset
					+ lineOffset);
				if (ch >= 33 && ch <= 126)
					sendResponse("%c", ch);
				else
					sendResponse(".");
			}
			
			lineStartOffset += LINE_LENGTH;
			sendResponse("\n");
		}
	}
}

static void doSetStrand(const char *options[], int optionCount)
{
	if (optionCount == 0)
		sendResponse("Current strand is %d\n", getCurrentStrand(gCore));
	else if (optionCount == 1)
	{
		unsigned int strand;
		if (!parseNumber(options[0], &strand) || strand > 3)
			sendResponse("Bad strand ID\n");
		else
			setCurrentStrand(gCore, strand);

		sendResponse("Current strand is %d\n", getCurrentStrand(gCore));
	}
	else
		sendResponse("needs only one param\n");
}

static void printBreakpoint(unsigned int address)
{
	sendResponse(" %08x\n", address);
}

static void doListBreakpoints(const char *options[], int optionCount)
{
	sendResponse("Breakpoints:\n");
	forEachBreakpoint(gCore, printBreakpoint);
}

static void doHelp(const char *options[], int optionCount);

static struct 
{
	const char *name;
	CommandDispatchFunction function;
} commandTable[] = {
	{ "regs", doRegs },
	{ "step", doSingleStep },
	{ "resume", doResume },
	{ "delete-breakpoint", doDeleteBreakpoint },
	{ "set-breakpoint", doSetBreakpoint },
	{ "breakpoints", doListBreakpoints },
	{ "read-memory", doReadMemory },
	{ "strand", doSetStrand },
	{ "help", doHelp },
	{ "quit", doQuit },
	{ NULL, NULL }
};

static void doHelp(const char *options[], int optionCount)
{
	int i;

	sendResponse("Available commands:\n");
	for (i = 0; commandTable[i].name != NULL; i++)
		sendResponse("  %s\n", commandTable[i].name);
}

static CommandDispatchFunction lookupCommand(const char *name)
{
	int i;
	
	for (i = 0; commandTable[i].name != NULL; i++)
	{
		if (strcmp(name, commandTable[i].name) == 0)
			return commandTable[i].function;
	}
	
	return NULL;
}

static void processLine(char *line)
{
	char *c;
	const char *tokens[MAX_TOKENS];
	int tokenCount = 1;
	CommandDispatchFunction func;
	const char *cmd;

	cmd = line;
	c = line;	
	while (*c != '\0')
	{
		if (isspace(*c))
		{
			*c = '\0';
			tokens[tokenCount++] = c + 1;
			if (tokenCount == MAX_TOKENS)
				break;	
		}
		
		c++;
	}

	func = lookupCommand(cmd);
	if (func == NULL)
		sendResponse("\nUnknown command %s (try 'help')\n", cmd);
	else
		(*func)(&tokens[1], tokenCount - 1);

}

// Receive commands from the GDB controller
void commandInterfaceReadLoop(Core *core)
{
	gCore = core;
	signal(SIGINT, handleControlC);

	for (;;)
	{
		char *command = readline("(dbg) ");
		if (command && *command)
			add_history(command);

		processLine(command);
	}
}
