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

#include "mmu-test-common.h"

unsigned int globaltmp;

// Test that writing memory mapped I/O from a supervisor page from 
// user mode faults.

void fault_handler()
{
	printf("FAULT %d %08x current flags %02x prev flags %02x\n", 
		__builtin_nyuzi_read_control_reg(CR_FAULT_REASON),
		__builtin_nyuzi_read_control_reg(CR_FAULT_ADDRESS),
		__builtin_nyuzi_read_control_reg(CR_FLAGS),
		__builtin_nyuzi_read_control_reg(CR_SAVED_FLAGS));
	exit(0);
}

// Make this a call to flush the pipeline
void switch_to_user_mode() __attribute__((noinline))
{
	__builtin_nyuzi_write_control_reg(CR_FLAGS, FLAG_MMU_EN);
}

int main(void)
{
	unsigned int va;
	int asid;
	unsigned int stack_addr = (unsigned int) &va & ~(PAGE_SIZE - 1);

	// Map code & data
	for (va = 0; va < 0x10000; va += PAGE_SIZE)
	{
		add_itlb_mapping(va, va);
		add_dtlb_mapping(va, va | TLB_WRITABLE | TLB_GLOBAL);
	}

	add_dtlb_mapping(stack_addr, stack_addr | TLB_WRITABLE);
	add_dtlb_mapping(IO_REGION_BASE, IO_REGION_BASE | TLB_SUPERVISOR | TLB_WRITABLE);

	// Alias mapping that we will use for test (the normal mapped region is used
	// to halt the test).
	add_dtlb_mapping(0x100000, IO_REGION_BASE | TLB_SUPERVISOR | TLB_WRITABLE);
	
	__builtin_nyuzi_write_control_reg(CR_FAULT_HANDLER, fault_handler);
	__builtin_nyuzi_write_control_reg(CR_FLAGS, FLAG_MMU_EN | FLAG_SUPERVISOR_EN);

	// Can write to page in supervisor mode
	globaltmp = *((volatile unsigned int*) 0x100000);
	printf("check1\n");
	// CHECK: check1

	// Switch to user mode, but leave MMU active
	switch_to_user_mode();

	*((volatile unsigned int*) 0x100000) = 0x12;
	// CHECK: FAULT 8 00100000 current flags 06 prev flags 02
	
	// XXX no way to verify that the write wasn't sent to external bus
}

