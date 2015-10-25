// 
// Copyright 2015 Jeff Bush
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

#define FILL_SIZE 0x80000
#define PAGE_SIZE 0x1000

extern void tlb_miss_handler();
extern void enable_mmu();

int main(void)
{
	unsigned int rand_seed;
	int offset;
	int *mem_region = (int*) 0x400000;

	// Enable MMU in flags register
	__builtin_nyuzi_write_control_reg(7, tlb_miss_handler);
	enable_mmu();

	// Fill memory region
	rand_seed = 0x2e48fa04;
	for (offset = 0; offset < FILL_SIZE / sizeof(int); offset += PAGE_SIZE 
		/ sizeof(int))
	{
		mem_region[offset] = rand_seed;
		rand_seed = rand_seed * 1664525 + 1013904223;
	}

	// Check memory region
	rand_seed = 0x2e48fa04;
	for (offset = 0; offset < FILL_SIZE / sizeof(int); offset += PAGE_SIZE 
		/ sizeof(int))
	{
		if (mem_region[offset] != rand_seed)
		{
			printf("FAIL: Mismatch at offset %d\n", offset);
			exit(1);
		}
		
		rand_seed = rand_seed * 1664525 + 1013904223;
	}
	
	printf("PASS\n");
}
