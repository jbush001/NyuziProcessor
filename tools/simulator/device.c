#include <assert.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <unistd.h>
#include <fcntl.h>
#include <sys/mman.h>
#include "core.h"

#define KEY_BUFFER_SIZE 32

static unsigned int blockDevReadAddress;
static unsigned int *blockDevData;
static unsigned int blockDevSize;
static int blockFd = -1;
static unsigned int keyBuffer[KEY_BUFFER_SIZE];
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
	unsigned int value;
	
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
				unsigned int result = blockDevData[blockDevReadAddress / 4];
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
			
			return value;

		default:
			return 0xffffffff;
	}
}

void enqueueKey(unsigned int scanCode)
{
	keyBuffer[keyBufferHead] = scanCode;
	keyBufferHead = (keyBufferHead + 1) % KEY_BUFFER_SIZE;

	// If the buffer is full, discard the oldest character
	if (keyBufferHead == keyBufferTail)	
		keyBufferTail = (keyBufferTail + 1) % KEY_BUFFER_SIZE;
}
