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
#include <sys/types.h>
#include <sys/stat.h>
#include <unistd.h>
#include <stdio.h>
#include <fcntl.h>
#include <sys/mman.h>
#include <sys/time.h>
#include "core.h"

#define KEY_BUFFER_SIZE 32

static uint32_t blockDevReadAddress;
static uint32_t *blockDevData;
static size_t blockDevSize;
static int blockFd = -1;
static uint32_t keyBuffer[KEY_BUFFER_SIZE];
static int keyBufferHead;
static int keyBufferTail;

int openBlockDevice(const char *filename)
{
	struct stat fs;
	if (blockFd != -1)
		return 0;	// Already open

	if (stat(filename, &fs) < 0)
	{
		perror("stat");
		return 0;
	}
	
	blockDevSize = fs.st_size;	
	blockFd = open(filename, O_RDONLY);
	if (blockFd < 0)
	{
		perror("open");
		return 0;
	}
	
	blockDevData = mmap(NULL, blockDevSize, PROT_READ, MAP_SHARED, blockFd, 0); 
	if (blockDevData == NULL)
		return 0;

	printf("Loaded block device %lu bytes\n", blockDevSize);
	return 1;
}

void closeBlockDevice()
{
	assert(blockFd > 0);
	close(blockFd);
}

void writeDeviceRegister(uint32_t address, uint32_t value)
{
	if (address == 0x20)
		printf("%c", value & 0xff); // Serial output
	else if (address == 0x30)
		blockDevReadAddress = value;
}

uint32_t readDeviceRegister(uint32_t address)
{
	uint32_t value;
	
	switch (address)
	{
		// These dummy values match ones hard coded in the verilog testbench.
		// Used for validating I/O transactions in cosimulation.
		case 0x4:
			return 0x12345678;
		case 0x8:
			return 0xabcdef9b;
		case 0x18:	// Serial status
			return 1;
		case 0x34:
			if (blockDevReadAddress < blockDevSize)
			{
				uint32_t result = blockDevData[blockDevReadAddress / 4];
				blockDevReadAddress += 4;
				return result;
			}
			else
				return 0xffffffff;

		case 0x38:
			// Keyboard status
			if (keyBufferHead != keyBufferTail)
				return 1;
			else
				return 0;

		case 0x3c:
			// Keyboard scancode
			if (keyBufferHead != keyBufferTail)
			{
				value = keyBuffer[keyBufferTail];
				keyBufferTail = (keyBufferTail + 1) % KEY_BUFFER_SIZE;
			}
			else
				value = 0;
			
			return value;
			
		case 0x40:
			// real time clock
			{
				struct timeval tv;
				gettimeofday(&tv, NULL);
				return tv.tv_sec * 1000000 + tv.tv_usec;
			}

		default:
			return 0xffffffff;
	}
}

void enqueueKey(uint32_t scanCode)
{
	keyBuffer[keyBufferHead] = scanCode;
	keyBufferHead = (keyBufferHead + 1) % KEY_BUFFER_SIZE;

	// If the buffer is full, discard the oldest character
	if (keyBufferHead == keyBufferTail)	
		keyBufferTail = (keyBufferTail + 1) % KEY_BUFFER_SIZE;
}
