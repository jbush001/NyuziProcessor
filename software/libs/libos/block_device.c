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

static volatile unsigned int * const REGISTERS = (volatile unsigned int*) 0xffff0000;

void read_block_device(unsigned int block_address, void *ptr)
{
	int i;
	
	REGISTERS[0x30 / 4] = block_address & ~(BLOCK_SIZE - 1);
	for (i = 0; i < BLOCK_SIZE / 4; i++)
		((unsigned int*) ptr)[i] = REGISTERS[0x34 / 4];
}
