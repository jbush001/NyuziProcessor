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
#include <stdio.h>
#include <sys/mman.h>
#include <sys/stat.h>
#include <sys/time.h>
#include <sys/types.h>
#include <unistd.h>
#include "core.h"
#include "device.h"
#include "sdmmc.h"

#define KEY_BUFFER_SIZE 32

static uint32_t keyBuffer[KEY_BUFFER_SIZE];
static int keyBufferHead;
static int keyBufferTail;

void writeDeviceRegister(uint32_t address, uint32_t value)
{
	switch (address)
	{
		case  0x20:
			printf("%c", value & 0xff); // Serial output
			break;

		case 0x44:
		case 0x50:
			writeSdCardRegister(address, value);
			break;
	}
}

uint32_t readDeviceRegister(uint32_t address)
{
	uint32_t value;
	
	switch (address)
	{
		case 0x18:	// Serial status
			return 1;

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
				return (uint32_t)(tv.tv_sec * 1000000 + tv.tv_usec);
			}

		case 0x48:
		case 0x4c:
			return readSdCardRegister(address);

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
