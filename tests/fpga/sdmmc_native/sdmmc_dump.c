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
#include <sdmmc.h>

enum GPIONum {
	GPIO_SD_DAT0 = 0,
	GPIO_SD_DAT1 = 1,
	GPIO_SD_DAT2 = 2,
	GPIO_SD_DAT3 = 3,
	GPIO_SD_CMD = 4,
	GPIO_SD_CLK = 5
};

enum SDCommand
{
	SD_GO_IDLE = 0,
	SD_ALL_SEND_CID = 2,
	SD_SEND_RELATIVE_ADDR = 3,
	SD_SELECT_CARD = 7,
	SD_SEND_IF_COND = 8,
	SD_SEND_CSD = 9,
	SD_SEND_CID = 10,
	SD_STOP_TRANSMISSION = 12,
	SD_SET_BLOCKLEN = 16,
	SD_READ_SINGLE_BLOCK = 17,
	SD_SEND_OP_COND = 41,
	SD_APP_CMD = 55,
};

#define GPIO_IN 0
#define GPIO_OUT 1

static volatile unsigned int * const REGISTERS = (volatile unsigned int*) 0xffff0000;
static int currentDirection = 0;
static int currentValue = 0;

static const unsigned char kCrc7Table[256] = {
      0x00, 0x09, 0x12, 0x1b, 0x24, 0x2d, 0x36, 0x3f,
      0x48, 0x41, 0x5a, 0x53, 0x6c, 0x65, 0x7e, 0x77,
      0x19, 0x10, 0x0b, 0x02, 0x3d, 0x34, 0x2f, 0x26,
      0x51, 0x58, 0x43, 0x4a, 0x75, 0x7c, 0x67, 0x6e,
      0x32, 0x3b, 0x20, 0x29, 0x16, 0x1f, 0x04, 0x0d,
      0x7a, 0x73, 0x68, 0x61, 0x5e, 0x57, 0x4c, 0x45,
      0x2b, 0x22, 0x39, 0x30, 0x0f, 0x06, 0x1d, 0x14,
      0x63, 0x6a, 0x71, 0x78, 0x47, 0x4e, 0x55, 0x5c,
      0x64, 0x6d, 0x76, 0x7f, 0x40, 0x49, 0x52, 0x5b,
      0x2c, 0x25, 0x3e, 0x37, 0x08, 0x01, 0x1a, 0x13,
      0x7d, 0x74, 0x6f, 0x66, 0x59, 0x50, 0x4b, 0x42,
      0x35, 0x3c, 0x27, 0x2e, 0x11, 0x18, 0x03, 0x0a,
      0x56, 0x5f, 0x44, 0x4d, 0x72, 0x7b, 0x60, 0x69,
      0x1e, 0x17, 0x0c, 0x05, 0x3a, 0x33, 0x28, 0x21,
      0x4f, 0x46, 0x5d, 0x54, 0x6b, 0x62, 0x79, 0x70,
      0x07, 0x0e, 0x15, 0x1c, 0x23, 0x2a, 0x31, 0x38,
      0x41, 0x48, 0x53, 0x5a, 0x65, 0x6c, 0x77, 0x7e,
      0x09, 0x00, 0x1b, 0x12, 0x2d, 0x24, 0x3f, 0x36,
      0x58, 0x51, 0x4a, 0x43, 0x7c, 0x75, 0x6e, 0x67,
      0x10, 0x19, 0x02, 0x0b, 0x34, 0x3d, 0x26, 0x2f,
      0x73, 0x7a, 0x61, 0x68, 0x57, 0x5e, 0x45, 0x4c,
      0x3b, 0x32, 0x29, 0x20, 0x1f, 0x16, 0x0d, 0x04,
      0x6a, 0x63, 0x78, 0x71, 0x4e, 0x47, 0x5c, 0x55,
      0x22, 0x2b, 0x30, 0x39, 0x06, 0x0f, 0x14, 0x1d,
      0x25, 0x2c, 0x37, 0x3e, 0x01, 0x08, 0x13, 0x1a,
      0x6d, 0x64, 0x7f, 0x76, 0x49, 0x40, 0x5b, 0x52,
      0x3c, 0x35, 0x2e, 0x27, 0x18, 0x11, 0x0a, 0x03,
      0x74, 0x7d, 0x66, 0x6f, 0x50, 0x59, 0x42, 0x4b,
      0x17, 0x1e, 0x05, 0x0c, 0x33, 0x3a, 0x21, 0x28,
      0x5f, 0x56, 0x4d, 0x44, 0x7b, 0x72, 0x69, 0x60,
      0x0e, 0x07, 0x1c, 0x15, 0x2a, 0x23, 0x38, 0x31,
      0x46, 0x4f, 0x54, 0x5d, 0x62, 0x6b, 0x70, 0x79
};

static void setDirection(int gpio, int out)
{
	if (out)
		currentDirection |= (1 << gpio);
	else
		currentDirection &= ~(1 << gpio);

	REGISTERS[0x58 / 4] = currentDirection;
}

static void setValue(int gpio, int value)
{
	if (value)
		currentValue |= (1 << gpio);
	else
		currentValue &= ~(1 << gpio);
	
	REGISTERS[0x5c / 4] = currentValue;
}

static int getValue(int gpio)
{
	return (REGISTERS[0x5c / 4] >> gpio) & 1;
}

void usleep(int wait)
{
	while (wait--)
		asm volatile("nop");
}

static void sdSendByte(int value)
{
	int i;

	for (i = 0; i < 8; i++)
	{
		setValue(GPIO_SD_CLK, 0);
		setValue(GPIO_SD_CMD, (value >> 7) & 1);
		setValue(GPIO_SD_CLK, 1);
		value <<= 1;
	}
}

static void sdSendCommand(int cval, unsigned int param)
{
	printf("send: ");
	
	int index;
	const char command[] = { 
		0x40 | cval, 
		(param >> 24) & 0xff,
		(param >> 16) & 0xff,
		(param >> 8) & 0xff,
		param & 0xff
	};

	setDirection(GPIO_SD_CMD, GPIO_OUT);
	int crc = 0;
	for (index = 0; index < 5; index++)
		crc = kCrc7Table[(crc << 1) ^ command[index]];
	
	for (index = 0; index < 5; index++)
	{
		sdSendByte(command[index]);
		printf("%02x ", command[index]);
	}
	
	sdSendByte((crc << 1) | 1);
	printf("%02x ", (crc << 1) | 1);
	printf("\n");
}

static int sdReceiveResponse(unsigned char *outResponse, int length, int hasCrc)
{
	int timeout = 10000;
	int bit;
	int byte;
	int byteIndex = 0;
	unsigned char crc;
	
	setDirection(GPIO_SD_CMD, GPIO_IN);

	// Wait for start bit
	while (timeout > 0)
	{
		setValue(GPIO_SD_CLK, 0);
		setValue(GPIO_SD_CLK, 1);
		if (getValue(GPIO_SD_CMD) == 0)
			break;

		timeout--;
	}
	
	if (timeout == 0)
	{
		printf("command timeout\n");
		return -1;
	}

	printf("receive: ");
	// Shift in rest of packet
	bit = 6;
	byte = 0;
	crc = 0;
	while (byteIndex < length)
	{
		setValue(GPIO_SD_CLK, 0);
		setValue(GPIO_SD_CLK, 1);

		byte = (byte << 1) | getValue(GPIO_SD_CMD);
		if (bit-- == 0)
		{
			outResponse[byteIndex++] = byte;
			printf("%02x ", byte);
			byte = 0;
			bit = 7;
		}
	}
	printf("\n");
	
	if (hasCrc)
	{
		for (byteIndex = 0; byteIndex < length - 1; byteIndex++)
			crc = kCrc7Table[(crc << 1) ^ outResponse[byteIndex]];
	
		if (((crc << 1) | 1) != outResponse[length - 1])
			printf("bad framing/CRC want %02x got %02x\n", ((crc << 1) | 1), outResponse[length - 1]);
	}
	else if ((outResponse[length - 1] & 1) != 1)
		printf("bad framing bit\n");

	// Send a dummy byte
	setDirection(GPIO_SD_CLK, GPIO_OUT);
	sdSendByte(0xff);

	return length;
}

static int readSdData(void *data)
{
	int byteIndex;
	int bitIndex;
	int timeout = 10000;

	// Wait for start bit
	while (timeout > 0)
	{
		setValue(GPIO_SD_CLK, 0);
		if (getValue(GPIO_SD_DAT0) == 0)
			break;

		setValue(GPIO_SD_CLK, 1);
		timeout--;
	}
	
	if (timeout == 0)
	{
		printf("timeout in readSdData\n");
		return -1;
	}
	
	for (byteIndex = 0; byteIndex < 512; byteIndex++)
	{
		unsigned int byteValue = 0;
		for (bitIndex = 0; bitIndex < 8; bitIndex++)
		{
			setValue(GPIO_SD_CLK, 0);
			byteValue = (byteValue << 1) | getValue(GPIO_SD_DAT0);
			setValue(GPIO_SD_CLK, 1);
		}
		
		((char*) data)[byteIndex] = byteValue;
	}

	// Read CRC
	for (bitIndex = 0; bitIndex < 16; bitIndex++)
	{
		setValue(GPIO_SD_CLK, 0);
		setValue(GPIO_SD_CLK, 1);
	}

	// Check end bit
	setValue(GPIO_SD_CLK, 0);
    if (getValue(GPIO_SD_DAT0) != 1)
	{
		printf("Framing error at end of data\n");
		return -1;
	}

	setValue(GPIO_SD_CLK, 1);
	
	return 512;
}

int main()
{
	int i;
	unsigned char data[512];
	unsigned char response[32];
	
	setDirection(GPIO_SD_CLK, GPIO_OUT);
	setDirection(GPIO_SD_CMD, GPIO_OUT);
	setValue(GPIO_SD_CMD, 1);

	printf("initialize\n");
	
	// 6.4.1.1: Device may use up to 74 clocks for preparation before 
	// receiving the first command. 
	for (i = 0; i < 80; i++)
	{
		setValue(GPIO_SD_CLK, 0);
		setValue(GPIO_SD_CLK, 1);
	}

	// Reset card, 4.2.1 
	sdSendCommand(SD_GO_IDLE, 0);
	sdSendByte(0xff);
	
	// 4.2.2 It is mandatory to issue CMD8 prior to first ACMD41 to initialize 
	// SDHC or SDXC Card 
	printf("sending IF_COND\n");
	sdSendCommand(SD_SEND_IF_COND, (1 << 8));	// Supply voltage 3.3V
	sdReceiveResponse(response, 6, 1);

	// Set voltage level, wait for card ready 4.2.3
	do
	{
		usleep(100000);
		printf("sending CMD55\n");
		sdSendCommand(SD_APP_CMD, 0);
		sdReceiveResponse(response, 6, 1);
		printf("sending ACMD41\n");
		sdSendCommand(SD_SEND_OP_COND, (1 << 20) | (1 << 30) | (1 << 28));	// 3.3V, XD, no power save
		sdReceiveResponse(response, 6, 0);
	}
	while ((response[1] & 0x80) == 0);
	
	printf("sending CMD2\n");
	sdSendCommand(SD_ALL_SEND_CID, 0);
	sdReceiveResponse(response, 17, 0);

	// Get the relative address of the card
	printf("sending CMD3\n");
	sdSendCommand(SD_SEND_RELATIVE_ADDR, 0);
	sdReceiveResponse(response, 6, 1);

	int rca = (response[1] << 8) | response[2];
	printf("RCA is %d\n", rca);

	// Select the card, using the relative address returned from CMD3
	printf("sending CMD7\n");
	sdSendCommand(SD_SELECT_CARD, (rca << 16));
	sdReceiveResponse(response, 6, 1);

	printf("sending READ_SINGLE_BLOCK\n");
	sdSendCommand(SD_READ_SINGLE_BLOCK, 0);
	sdReceiveResponse(response, 6, 1);
	
	unsigned int statusValue = (response[1] << 24) | (response[2] << 16) | (response[3] << 8)
		| response[4];
	if ((statusValue >> 13) != 0)
		printf("Error: %05x\n", statusValue >> 13);
	
	if (((statusValue >> 9) & 15) != 4)	// state tran
		printf("Bad status %d\n", ((statusValue >> 9) & 15));

	printf("receiving data\n");
	if (readSdData(data) < 0)
		return 1;

	printf("done\n");
	for (int address = 0; address < BLOCK_SIZE; address += 16)
	{
		printf("%08x ", address);
		for (int offset = 0; offset < 16; offset++)
			printf("%02x ", data[address + offset]);
		
		printf("  ");
		for (int offset = 0; offset < 16; offset++)
		{
			unsigned char c = data[address + offset];
			if (c >= 32 && c <= 128)
				printf("%c ", c);
			else
				printf(".");
		}

		printf("\n");
	}

	return 0;
}
