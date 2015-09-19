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

#include "protocol.h"

//
// First stage serial bootloader. This is synthesized into ROM in high memory
// in the FPGA configuration. It supports a simple protocol that allows 
// loading a program into memory. It communicates with a host side loader in 
// tool/serial_boot.
//

volatile unsigned int * const LED_BASE = (volatile unsigned int*) 0xFFFF0000;
volatile unsigned int * const UART_BASE = (volatile unsigned int*) 0xFFFF0018;
	
enum UartRegs
{
	kStatus = 0,
	kRx = 1,
	kTx = 2
};

unsigned int read_serial_byte(void)
{
	while ((UART_BASE[kStatus] & 2) == 0)	
		;
	
	return UART_BASE[kRx];
}

void write_serial_byte(unsigned int ch)
{
	while ((UART_BASE[kStatus] & 1) == 0)	// Wait for ready
		;
	
	UART_BASE[kTx] = ch;
}

unsigned int read_serial_long(void)
{
	unsigned int result = 0;
	for (int i = 0; i < 4; i++)
		result = (result >> 8) | (read_serial_byte() << 24);

	return result;
}

void write_serial_long(unsigned int value)
{
	write_serial_byte(value & 0xff);
	write_serial_byte((value >> 8) & 0xff);
	write_serial_byte((value >> 16) & 0xff);
	write_serial_byte((value >> 24) & 0xff);
}

void *memset(void *_dest, int value, unsigned int length)
{
	char *dest = (char*) _dest;
	value &= 0xff;

	if ((((unsigned int) dest) & 3) == 0)
	{
		// Write 4 bytes at a time.
		unsigned wideVal = value | (value << 8) | (value << 16) | (value << 24);
		while (length > 4)
		{
			*((unsigned int*) dest) = wideVal;
			dest += 4;
			length -= 4;
		}		
	}

	// Write one byte at a time
	while (length > 0)
	{
		*dest++ = value;
		length--;
	}
	
	return _dest;	
}

int main()
{
	LED_BASE[0] = 0x1;	// Turn on LED
	
	for (;;)
	{
		switch (read_serial_byte())
		{
			case LOAD_MEMORY_REQ:
			{
				unsigned int baseAddress = read_serial_long();
				unsigned int length = read_serial_long();

				// Compute fletcher checksum of data
				unsigned int checksuma = 0;
				unsigned int checksumb = 0;
				
				for (int i = 0; i < length; i++)
				{
					unsigned int ch = read_serial_byte();
					checksuma += ch;
					checksumb += checksuma;
					((unsigned char*) baseAddress)[i] = ch;
				}

				write_serial_byte(LOAD_MEMORY_ACK);
				write_serial_long((checksuma & 0xffff) | ((checksumb & 0xffff) << 16));
				break;
			}
			
			case CLEAR_MEMORY_REQ:
			{
				unsigned int baseAddress = read_serial_long();
				unsigned int length = read_serial_long();
				memset((char*) 0 + baseAddress, 0, length);
				write_serial_byte(CLEAR_MEMORY_ACK);
				break;
			}
			
			case EXECUTE_REQ:
			{
				LED_BASE[0] = 0;	// Turn off LED
				write_serial_byte(EXECUTE_ACK);
				return 0;	// Break out of main
			}
			
			case PING_REQ:
				write_serial_byte(PING_ACK);
				break;
			
			default:
				write_serial_byte(BAD_COMMAND);
		}
	}
}


