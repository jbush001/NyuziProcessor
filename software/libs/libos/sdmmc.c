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
#include "registers.h"
#include "sdmmc.h"

// SPI mode SDMMC driver. This currently only works in the emulator/verilog
// simulator. I'm still debugging this on FPGA. In order to use this on FPGA,
// the SPI interface must be enabled by making sure the define BITBANG_SDMMC 
// is not set in rtl/fpga/fpga_top.sv.

#define SYS_CLOCK_HZ 50000000
#define MAX_RETRIES 100

typedef enum 
{
	SD_CMD_RESET = 0,
	SD_CMD_INIT = 1,
	SD_CMD_SET_BLOCK_LEN = 0x16,
	SD_CMD_READ_BLOCK = 0x17
} SDCommand;

static void setCs(int level)
{
	REGISTERS[REG_SD_SPI_CONTROL] = level;
}

static void setClockDivisor(int divisor)
{
	REGISTERS[REG_SD_SPI_CLOCK_DIVIDE] = divisor - 1;
}

// Transfer a single byte bidirectionally.
static int spiTransfer(int value)
{
	REGISTERS[REG_SD_SPI_WRITE] = value & 0xff;
	while ((REGISTERS[REG_SD_SPI_STATUS] & 1) == 0)
		;	// Wait for transfer to finish

	return REGISTERS[REG_SD_SPI_READ];
}

static int sendSdCommand(SDCommand command, unsigned int parameter)
{
	int result;
	int retryCount = 0;

	spiTransfer(0x40 | command);	
	spiTransfer((parameter >> 24) & 0xff);
	spiTransfer((parameter >> 16) & 0xff);
	spiTransfer((parameter >> 8) & 0xff);
	spiTransfer(parameter & 0xff);
	spiTransfer(0x95);	// Checksum (ignored for all but first command)

	// Wait while card is busy
	do
	{
		result = spiTransfer(0xff);
	}
	while (result == 0xff && retryCount++ < MAX_RETRIES);
	
	return result;
}

int initSdmmcDevice()
{
	int result;
	
	// Set clock to 200kHz (50Mhz system clock)
	setClockDivisor(125);	

	// After power on, send a bunch of clocks to initialize the chip
	setCs(1);
	for (int i = 0; i < 10; i++)
		spiTransfer(0xff);

	setCs(0);

	// Reset the card
	result = sendSdCommand(SD_CMD_RESET, 0);
	if (result != 1)
	{
		printf("initSdmmcDevice: error %d SD_CMD_RESET\n", result);
		return -1;
	}

	// Poll until it is ready
	while (1)
	{
		result = sendSdCommand(SD_CMD_INIT, 0);
		if (result == 0)
			break;
		
		if (result != 1)
		{
			printf("initSdmmcDevice: error %d SD_CMD_INIT\n", result);
			return -1;
		}
	}

	// Configure the block size
	result = sendSdCommand(SD_CMD_SET_BLOCK_LEN, BLOCK_SIZE);
	if (result != 0)
	{
		printf("initSdmmcDevice: error %d SD_CMD_SET_BLOCK_LEN\n", result);
		return -1;
	}
		
	// Increase clock rate to 5 Mhz
	setClockDivisor(5);	
	
	return 0;
}

int readSdmmcDevice(unsigned int blockAddress, void *ptr)
{
	int result;
	
	result = sendSdCommand(SD_CMD_READ_BLOCK, blockAddress);
	if (result != 0)
	{
		printf("readSdmmcDevice: error %d SD_CMD_READ_BLOCK\n", result);
		return -1;
	}
	
	for (int i = 0; i < BLOCK_SIZE; i++)
		((char*) ptr)[i] = spiTransfer(0xff);
	
	// checksum (ignored)
	spiTransfer(0xff);	
	spiTransfer(0xff);
	
	return BLOCK_SIZE;
}
