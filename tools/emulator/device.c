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

#define KEY_BUFFER_SIZE 64

static uint32_t keyBuffer[KEY_BUFFER_SIZE];
static int keyBufferHead;
static int keyBufferTail;

void writeDeviceRegister(uint32_t address, uint32_t value)
{
	switch (address)
	{
		case DEV_SERIAL_OUTPUT:
			printf("%c", value & 0xff); // Serial output
			break;

		case DEV_SD_WRITE_DATA:
		case DEV_SD_CONTROL:
			writeSdCardRegister(address, value);
			break;
	}
}

uint32_t readDeviceRegister(uint32_t address)
{
	uint32_t value;
	
	switch (address)
	{
		case DEV_SERIAL_STATUS:	// Serial status
			return 1;

		case DEV_KEYBOARD_STATUS:
			// Keyboard status
			if (keyBufferHead != keyBufferTail)
				return 1;
			else
				return 0;

		case DEV_KEYBOARD_READ:
			// Keyboard scancode
			if (keyBufferHead != keyBufferTail)
			{
				value = keyBuffer[keyBufferTail];
				keyBufferTail = (keyBufferTail + 1) % KEY_BUFFER_SIZE;
			}
			else
				value = 0;
			
			return value;

		case DEV_REAL_TIME_CLOCK:
			// real time clock
			{
				struct timeval tv;
				gettimeofday(&tv, NULL);
				return (uint32_t)(tv.tv_sec * 1000000 + tv.tv_usec);
			}

		case DEV_SD_READ_DATA:
		case DEV_SD_STATUS:
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
