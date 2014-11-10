#include <assert.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <unistd.h>
#include <fcntl.h>
#include <sys/mman.h>
#include "core.h"

static unsigned int blockDevReadAddress;
static unsigned int *blockDevData;
static unsigned int blockDevSize;
static int blockFd = -1;

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

	printf("Loaded block device %d bytes\n", blockDevSize);
	return 1;
}

void closeBlockDevice()
{
	assert(blockFd > 0);
	fclose(blockFd);
}

void writeDeviceRegister(unsigned int address, unsigned int value)
{
	if (address == 0x20)
		printf("%c", value & 0xff); // Serial output
	else if (address == 0x30)
		blockDevReadAddress = value;
}

unsigned readDeviceRegister(unsigned int address)
{
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
				return blockDevData[blockDevReadAddress / 4];
				blockDevReadAddress += 4;
			}
			else
				return 0xffffffff;

		default:
			return 0xffffffff;
	}
}

