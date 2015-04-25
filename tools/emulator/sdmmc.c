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

#include <assert.h>
#include <fcntl.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <sys/mman.h>
#include <sys/stat.h>
#include <unistd.h>
#include "sdmmc.h"

#define INIT_CLOCKS 48

enum SdState
{
	kInitWaitForClocks,
	kIdle,
	kReceiveCommand,
	kWaitReadResponse,
	kSendResult,
	kDoRead
};

static uint8_t *gBlockDevData;
static uint32_t gBlockDevSize;
static int gBlockFd = -1;

static enum SdState gCurrentState;
static int gChipSelect;
static int gStateDelay;
static uint32_t gReadOffset;
static uint32_t gBlockLength;
static uint8_t gResponseValue;
static int gInitClockCount;
static int gCommandResult;
static int gResetDelay;
static uint8_t gCurrentCommand[6];
static int gCurrentCommandLength;
int gIsReset;

int openBlockDevice(const char *filename)
{
	struct stat fs;
	if (gBlockFd != -1)
		return 0;	// Already open

	if (stat(filename, &fs) < 0)
	{
		perror("stat");
		return 0;
	}
	
	gBlockDevSize = fs.st_size;	
	gBlockFd = open(filename, O_RDONLY);
	if (gBlockFd < 0)
	{
		perror("open");
		return 0;
	}
	
	gBlockDevData = mmap(NULL, gBlockDevSize, PROT_READ, MAP_SHARED, gBlockFd, 0); 
	if (gBlockDevData == NULL)
		return 0;

	printf("Loaded block device %d bytes\n", gBlockDevSize);
	return 1;
}

void closeBlockDevice()
{
	assert(gBlockFd > 0);
	close(gBlockFd);
}

unsigned int convertValue(const uint8_t values[4])
{
	return (values[0] << 24) | (values[1] << 16) | (values[2] << 8) | values[3];
}

static void processCommand(const uint8_t command[6])
{
	switch (command[0] & 0x3f)
	{
		case 0x0:	// Reset (CMD0)
			gIsReset = 1;
			gCurrentState = kSendResult;
			gCommandResult = 0;
			break;
		
		case 0x1:	// Initialize (CMD1)
			if (gResetDelay)
			{
				gCommandResult = 1;
				gResetDelay--;
			}
			else
				gCommandResult = 0;
			
			gCurrentState = kSendResult;
			break;

		case 0x16: // Set block length (CMD16)
			if (!gIsReset)
			{
				printf("set block length command issued, card not ready\n");
				exit(1);
			}

			gBlockLength = convertValue(command + 1);
			gCurrentState = kSendResult;
			gCommandResult = 0;
			break;
			
		case 0x17: // Read block (CMD17)
			if (!gIsReset)
			{
				printf("set block length command issued, card not ready\n");
				exit(1);
			}

			gReadOffset = convertValue(command + 1);
			gCurrentState = kWaitReadResponse;
			gStateDelay = rand() & 0xf;	// Wait a random amount of time
			break;
	}
}

void writeSdCardRegister(uint32_t address, uint32_t value)
{
	switch (address)
	{
		case 0x44:	// Write data
			switch (gCurrentState)
			{
				case kInitWaitForClocks:
					gInitClockCount += 8;
					if (gChipSelect && gInitClockCount < INIT_CLOCKS)
					{
						printf("sdmmc error: command posted before card initialized 1\n");
						exit(1);
					}
				
					// Falls through
					
				case kIdle:
					if (gChipSelect && (value & 0xc0) == 0x40)
					{
						gCurrentState = kReceiveCommand;
						gCurrentCommand[0] = value & 0xff;
						gCurrentCommandLength = 1;
					}

					break;
					
				case kReceiveCommand:
					if (gChipSelect)
					{
						gCurrentCommand[gCurrentCommandLength++] = value & 0xff;
						if (gCurrentCommandLength == 6)
						{
							processCommand(gCurrentCommand);
							gCurrentCommandLength = 0;
						}
					}

					break;
					
				case kSendResult:
					gResponseValue = gCommandResult;
					gCurrentState = kIdle;
					break;
					
				case kWaitReadResponse:
					if (gStateDelay == 0)
					{
						gCurrentState = kDoRead;
						gResponseValue = 0;	// Signal ready
						gStateDelay = gBlockLength;
					}
					else
					{
						gStateDelay--;
						gResponseValue = 0xff;	// Signal busy
					}
					
					break;

				case kDoRead:
					// Ignore transmitted byte, put read byte in buffer
					if (gStateDelay == 0)
					{
						gResponseValue = 0xff;	// Checksum
						gCurrentState = kIdle;
					}
					else
					{
						gResponseValue = gBlockDevData[gReadOffset];
						gReadOffset++;
						gStateDelay--;
					}
						
					break;
			}
			
			break;

		case 0x50:	// control
			gChipSelect = value & 1;
			break;
			
		default:
			assert("Should not be here" && 0);
	}
}

unsigned readSdCardRegister(uint32_t address)
{
	switch (address)
	{
		case 0x48: // read data
			return gResponseValue;
	
		case 0x4c: // status
			return 0x01;
	
		default:
			assert("Should not be here" && 0);
	}
}

