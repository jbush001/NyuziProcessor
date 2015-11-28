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

#include "mmu_test_common.h"

// Test that supervisor bits work properly for DTLB entries

void fault_handler()
{
	printf("FAULT %d current flags %02x prev flags %02x\n",
		__builtin_nyuzi_read_control_reg(CR_FAULT_REASON),
		__builtin_nyuzi_read_control_reg(CR_FLAGS),
		__builtin_nyuzi_read_control_reg(CR_SAVED_FLAGS));
	exit(0);
}

int main(void)
{
	unsigned int va;
	unsigned int stack_addr = (unsigned int) &va & ~(PAGE_SIZE - 1);

	// Map code & data
	for (va = 0; va < 0x10000; va += PAGE_SIZE)
	{
		add_itlb_mapping(va, va | TLB_SUPERVISOR);
		add_dtlb_mapping(va, va | TLB_WRITABLE | TLB_SUPERVISOR);
	}

	add_dtlb_mapping(stack_addr, stack_addr | TLB_WRITABLE);
	add_dtlb_mapping(IO_REGION_BASE, IO_REGION_BASE | TLB_WRITABLE);

	__builtin_nyuzi_write_control_reg(CR_FAULT_HANDLER, fault_handler);

	// Enable MMU
	__builtin_nyuzi_write_control_reg(CR_FLAGS, FLAG_MMU_EN | FLAG_SUPERVISOR_EN);

	printf("one flags %02x prev flags %02x\n",
		__builtin_nyuzi_read_control_reg(CR_FLAGS),
		__builtin_nyuzi_read_control_reg(CR_SAVED_FLAGS)); // CHECK: one flags 06 prev flags 04

	// Switch to user mode, but leave MMU active
	switch_to_user_mode();

	// This will fault on instruction fetch.  Interrupts should be enabled, but
	// the processor should be back in supervisor mode.
	printf("THIS IS USER MODE\n");	// CHECK: FAULT 9 current flags 06 prev flags 02

}

