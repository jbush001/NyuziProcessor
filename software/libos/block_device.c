// 
// Copyright (C) 2014 Jeff Bush
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

#include "block_device.h"

static volatile unsigned int * const REGISTERS = (volatile unsigned int*) 0xffff0000;

void read_block_device(unsigned int block_address, void *ptr)
{
	int i;
	
	REGISTERS[0x30 / 4] = block_address & ~(BLOCK_SIZE - 1);
	for (i = 0; i < BLOCK_SIZE / 4; i++)
		((unsigned int*) ptr)[i] = REGISTERS[0x34 / 4];
}
