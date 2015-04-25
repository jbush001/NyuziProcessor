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
#include "sdcard.h"

enum SdState
{
	kIdle,
	kSetReadAddress,
	kSetBlockLength,
	kWaitReadResponse,
	kSendResult,
	kDoRead
};

static enum SdState gCurrentState;
static int gChipSelect;
static int gStateCount;
static uint32_t gBlockAddress;
static uint32_t gBlockLength;
static uint8_t *gBlockDevData;
static uint32_t gBlockDevSize;
static int gBlockFd = -1;
static uint8_t gReadByte;


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

void writeSdCardRegister(uint32_t address, uint32_t value)
{
	switch (address)
	{
		case 0x44:	// Write data
			switch (gCurrentState)
			{
				case kIdle:
					if (gChipSelect)
					{
						switch (value)
						{
							case 0x57:	// CMD17, READ
								gCurrentState = kSetReadAddress;
								gStateCount = 5;
								break;
							
							case 0x56:	// CMD16, Set block length
								gCurrentState = kSetBlockLength;
								gStateCount = 5;
								break;
						}
					}
					
					break;
					
				case kSetReadAddress:
					if (--gStateCount == 0)
					{
						// ignore checksum
						gCurrentState = kWaitReadResponse;
						gStateCount = rand() & 0xf;	// Wait a random amount of time
					}
					else
						gBlockAddress = (gBlockAddress << 8) | (value & 0xff);

					break;
					
				case kSetBlockLength:
					if (--gStateCount == 0)
					{
						// ignore checksum
						gCurrentState = kSendResult;
					}
					else
						gBlockLength = (gBlockLength << 8) | (value & 0xff);
					
					break;
					
				case kSendResult:
					gReadByte = 0;
					gCurrentState = kIdle;
					break;
					
				case kWaitReadResponse:
					if (gStateCount == 0)
					{
						gCurrentState = kDoRead;
						gReadByte = 0;	// Signal ready
						gStateCount = gBlockLength;
					}
					else
					{
						gStateCount--;
						gReadByte = 0xff;	// Signal busy
					}
					
					break;

				case kDoRead:
					// Ignore transmitted byte, put read byte in buffer
					if (gStateCount == 0)
					{
						gReadByte = 0xff;	// Checksum
						gCurrentState = kIdle;
					}
					else
					{
						gReadByte = gBlockDevData[gBlockAddress];
						gBlockAddress++;
						gStateCount--;
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
			switch (gCurrentState)
			{
				case kDoRead:
				case kWaitReadResponse:
					return gReadByte;
					
				default:
					return 0;	// XXX not busy
			}
		
			break;
	
		case 0x4c: // status
			return 0x01;
	
		default:
			assert("Should not be here" && 0);
	}
}

