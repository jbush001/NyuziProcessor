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


#include "block_device.h"

#define SYS_CLOCK_HZ 50000000

#define SD_CMD_RESET 0
#define SD_CMD_GET_STATUS 1
#define SD_CMD_SET_SECTOR_SIZE 0x16
#define SD_CMD_READ 0x17

static volatile unsigned int * const REGISTERS = (volatile unsigned int*) 0xffff0000;

static void set_cs(int asserted)
{
	REGISTERS[0x50 / 4] = asserted;
}

static void set_clock_rate(int hz)
{
	REGISTERS[0x54 / 4] = ((SYS_CLOCK_HZ / hz) / 2) - 1;
}

// Transfer a single byte bidirectionally.
static int spi_transfer(int value)
{
	REGISTERS[0x44 / 4] = value & 0xff;
	while ((REGISTERS[0x4c / 4] & 1) == 0)
		;	// Wait for transfer to finish

	return REGISTERS[0x48 / 4];
}

static void send_sd_command(int command, unsigned int parameter)
{
	spi_transfer(0x40 | command);	
	spi_transfer((parameter >> 24) & 0xff);
	spi_transfer((parameter >> 16) & 0xff);
	spi_transfer((parameter >> 8) & 0xff);
	spi_transfer(parameter & 0xff);
	spi_transfer(0x95);	// Checksum (ignored)
}

static int get_result()
{
	int result;

	// Wait while card is busy
	do
	{
		result = spi_transfer(0xff);
	}
	while (result == 0xff);
	
	return result;
}

void init_block_device()
{
	// After power on, send a bunch of clocks to initialize the chip
	set_clock_rate(400000);	// Slow clock rate
	set_cs(0);
	for (int i = 0; i < 8; i++)
		spi_transfer(0xff);

	set_cs(1);

	// Reset the card
	send_sd_command(SD_CMD_RESET, 0);
	get_result();

	// Poll the card until it is ready
	do
	{
		send_sd_command(SD_CMD_GET_STATUS, 0);
	}
	while (get_result());

	// Configure the block size
	send_sd_command(SD_CMD_SET_SECTOR_SIZE, BLOCK_SIZE);
	get_result();
	set_cs(0);
	set_clock_rate(1800000);	// Faster clock rate
}

void read_block_device(unsigned int block_address, void *ptr)
{
	set_cs(1);
	send_sd_command(SD_CMD_READ, block_address);
	get_result();
	for (int i = 0; i < BLOCK_SIZE; i++)
		((char*) ptr)[i] = spi_transfer(0xff);
	
	spi_transfer(0xff);	// checksum (ignored)
	set_cs(0);
}
