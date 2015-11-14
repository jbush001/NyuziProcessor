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
#include <unistd.h>

#define PAGE_SIZE 0x1000
#define TLB_WRITE_ENABLE 2

volatile unsigned int *data_addr = (unsigned int*) 0x100000;
volatile unsigned int *data_addr2 = (unsigned int*) 0x101000;

void add_itlb_mapping(unsigned int va, unsigned int pa)
{
	asm("itlbinsert %0, %1" : : "r" (va), "r" (pa));
}

void add_dtlb_mapping(unsigned int va, unsigned int pa, int write_enable)
{
	asm("dtlbinsert %0, %1" : : "r" (va), "r" (pa | (write_enable ? TLB_WRITE_ENABLE : 0)));
}

void fault_handler()
{
	printf("FAULT %d %08x\n", __builtin_nyuzi_read_control_reg(3),
		__builtin_nyuzi_read_control_reg(5));
	printf("data value = %08x\n", data_addr[PAGE_SIZE / sizeof(int)]);
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
		add_dtlb_mapping(i * PAGE_SIZE, i * PAGE_SIZE, 1);
	}

	add_dtlb_mapping(stack_addr, stack_addr, 1);
	add_dtlb_mapping(data_addr, data_addr, 1);	// Writable
	*data_addr2 = 0x12345678; 
	add_dtlb_mapping(data_addr2, data_addr2, 0); // Not writable
	add_dtlb_mapping(0xffff0000, 0xffff0000, 1); // I/O

	// Enable MMU in flags register
	__builtin_nyuzi_write_control_reg(1, fault_handler);
	__builtin_nyuzi_write_control_reg(7, fault_handler);
	__builtin_nyuzi_write_control_reg(4, (1 << 1) | (1 << 2));

	// This should write successfully
	*data_addr = 0x1f6818aa;
	printf("data value %08x\n", *data_addr); // CHECK: data value 1f6818aa

	// Attempt to write to write protected page will fail.
	*data_addr2 = 0xdeadbeef; 

	// Ensure two things:
	// - that a fault is raised
	// - that the value isn't actually written
	// CHECK: FAULT 7 00101000
	// CHECK: data value = 12345678

	printf("Did not fault\n", data_addr[PAGE_SIZE / sizeof(int)]);
	return 0;
}
