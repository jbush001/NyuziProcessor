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
#include <string.h>

#define PAGE_SIZE 0x1000
#define TLB_WRITE_ENABLE 2
#define DATA_BASE 0x100000

//
// Ensure cache control instructions will cause a TLB miss if there isn't
// a mapping.
//

void add_itlb_mapping(unsigned int va, unsigned int pa)
{
	asm("itlbinsert %0, %1" : : "r" (va), "r" (pa));
}

void add_dtlb_mapping(unsigned int va, unsigned int pa)
{
	asm("dtlbinsert %0, %1" : : "r" (va), "r" (pa | TLB_WRITE_ENABLE));
}

void tlb_miss_handler()
{
	printf("FAULT %d %08x\n", __builtin_nyuzi_read_control_reg(3),
		__builtin_nyuzi_read_control_reg(5));
	exit(0);
}

int main(int argc, const char *argv[])
{
	int i;
	unsigned int stack_addr = (unsigned int) &i & ~(PAGE_SIZE - 1);

	// Map code & data
	for (i = 0; i < 8; i++)
	{
		add_itlb_mapping(i * PAGE_SIZE, i * PAGE_SIZE);
		add_dtlb_mapping(i * PAGE_SIZE, i * PAGE_SIZE);
	}

	// Stack
	add_dtlb_mapping(stack_addr, stack_addr);

	// Data
	add_dtlb_mapping(DATA_BASE, DATA_BASE);

	// I/O registers
	add_dtlb_mapping(0xffff0000, 0xffff0000);

	// Set up miss handler
	__builtin_nyuzi_write_control_reg(7, tlb_miss_handler);
	__builtin_nyuzi_write_control_reg(4, (1 << 1) | (1 << 2));	// Turn on MMU in flags

	// This dflush should already be present
	asm("dflush %0" : : "s" (DATA_BASE));

	printf("FLUSH1\n");	// CHECK: FLUSH1

	// This dflush should cause a TLB miss
	asm("dflush %0" : : "s" (DATA_BASE + PAGE_SIZE)); // CHECK: FAULT 6 00101000

	printf("didn't fault\n");

	return 0;
}
