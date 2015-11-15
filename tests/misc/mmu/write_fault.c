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
#include "mmu_test_common.h"

volatile unsigned int *data_addr = (unsigned int*) 0x100000;
volatile unsigned int *data_addr2 = (unsigned int*) 0x101000;

void fault_handler()
{
	printf("FAULT %d %08x\n", __builtin_nyuzi_read_control_reg(CR_FAULT_REASON),
		__builtin_nyuzi_read_control_reg(CR_FAULT_ADDRESS));
	printf("data value = %08x\n", data_addr[PAGE_SIZE / sizeof(int)]);
	exit(0);
}

int main(void)
{
	unsigned int va;
	unsigned int stack_addr = (unsigned int) &va & ~(PAGE_SIZE - 1);

	// Map code & data
	for (va = 0; va < 0x10000; va += PAGE_SIZE)
	{
		add_itlb_mapping(va, va | TLB_GLOBAL);
		add_dtlb_mapping(va, va | TLB_WRITABLE | TLB_GLOBAL);
	}

	add_dtlb_mapping(stack_addr, stack_addr | TLB_WRITABLE);
	add_dtlb_mapping(data_addr, ((unsigned int)data_addr) | TLB_WRITABLE);	// Writable
	*data_addr2 = 0x12345678; 
	add_dtlb_mapping(data_addr2, data_addr2); // Not writable
	add_dtlb_mapping(IO_REGION_BASE, IO_REGION_BASE | TLB_WRITABLE); // I/O

	// Enable MMU in flags register
	__builtin_nyuzi_write_control_reg(CR_FAULT_HANDLER, fault_handler);
	__builtin_nyuzi_write_control_reg(CR_TLB_MISS_HANDLER, fault_handler);
	__builtin_nyuzi_write_control_reg(CR_FLAGS, FLAG_MMU_EN | FLAG_SUPERVISOR_EN);

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
