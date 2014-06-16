// 
// Copyright (C) 2011-2014 Jeff Bush
// 
// This library is free software; you can redistribute it and/or
// modify it under the terms of the GNU Library General Public
// License as published by the Free Software Foundation; either
// version 2 of the License, or (at your option) any later version.
// 
// This library is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
// Library General Public License for more details.
// 
// You should have received a copy of the GNU Library General Public
// License along with this library; if not, write to the
// Free Software Foundation, Inc., 51 Franklin St, Fifth Floor,
// Boston, MA  02110-1301, USA.
// 

//
// 1st stage serial bootloader.
// This supports a simple protocol that allows loading a program into memory.
// It supports commands to initialize and load data into segments and jump
// to an execution address.  It is driven by a host side loader in
// tool/serial_boot.
//

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

enum Command
{
	kLoadDataReq = 0xc0,
	kLoadDataAck,
	kClearRangeReq,
	kClearRangeAck,
	kExecuteReq,
	kExecuteAck,
	kPingReq,
	kPingAck,
	kBadCommand
};

void *memset(void *_dest, int value, unsigned int length)
{
	char *dest = (char*) _dest;
	while (length > 0)
	{
		*dest++ = value;
		length--;
	}
	
	return _dest;
}

extern unsigned int startAddress;

void main()
{
	for (;;)
	{
		switch (read_serial_byte())
		{
			case kLoadDataReq:
			{
				unsigned int baseAddress = read_serial_long();
				unsigned int length = read_serial_long();
				unsigned int checksuma = 0;
				unsigned int checksumb = 0;
				
				for (int i = 0; i < length; i++)
				{
					unsigned int ch = read_serial_byte();
					checksuma += ch;
					checksumb += checksuma;
					((unsigned char*) baseAddress)[i] = ch;
				}


				write_serial_byte(kLoadDataAck);
				write_serial_long((checksuma & 0xffff) | ((checksumb & 0xffff) << 16));
				break;
			}
				
			case kClearRangeReq:
			{
				unsigned int baseAddress = read_serial_long();
				unsigned int length = read_serial_long();
				memset((void*) baseAddress, 0, length);
				write_serial_byte(kClearRangeAck);
				break;
			}
			
			case kExecuteReq:
			{
				startAddress = read_serial_long();
				write_serial_byte(kExecuteAck);
				return;	// Break out of main
			}
			
			case kPingReq:
				write_serial_byte(kPingAck);
				break;
			
			default:
				write_serial_byte(kBadCommand);
		}
	}
}


