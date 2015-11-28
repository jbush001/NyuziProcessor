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

// Virtual addresses are chosen to not alias with code or other pages
#define VADDR1 0x10a000
#define PADDR1 0x100000
#define PADDR2 0x101000

void fault_handler(void)
{
	printf("FAULT %d addr %08x pc %08x\n",
		__builtin_nyuzi_read_control_reg(CR_FAULT_REASON),
		__builtin_nyuzi_read_control_reg(CR_FAULT_ADDRESS),
		__builtin_nyuzi_read_control_reg(CR_FAULT_PC));
	exit(0);
}

int main(void)
{
	unsigned int va;
	int asid;
	unsigned int stack_addr = (unsigned int) &va & ~(PAGE_SIZE - 1);

	// Map code & data
	for (va = 0; va < 0x10000; va += PAGE_SIZE)
	{
		add_itlb_mapping(va, va | TLB_GLOBAL);
		add_dtlb_mapping(va, va | TLB_WRITABLE | TLB_GLOBAL);
	}

	add_dtlb_mapping(stack_addr, stack_addr | TLB_WRITABLE | TLB_GLOBAL);
	add_dtlb_mapping(IO_REGION_BASE, IO_REGION_BASE | TLB_WRITABLE | TLB_GLOBAL);

	// Map a private page into address space 1
	set_asid(1);
	add_dtlb_mapping(VADDR1, PADDR1);
	*((unsigned int*) PADDR1) = 0xdeadbeef;

	// Map a private page into address space 2
	set_asid(2);
	add_dtlb_mapping(VADDR1, PADDR2);
	*((unsigned int*) PADDR2) = 0xabcdefed;

	// Enable MMU in flags register
	__builtin_nyuzi_write_control_reg(CR_FAULT_HANDLER, fault_handler);
	__builtin_nyuzi_write_control_reg(CR_TLB_MISS_HANDLER, fault_handler);
	__builtin_nyuzi_write_control_reg(CR_FLAGS, FLAG_MMU_EN | FLAG_SUPERVISOR_EN);

	// Read value from first address space
	set_asid(1);
	printf("A1 %08x\n", *((volatile unsigned int*) VADDR1)); // CHECK: A1 deadbeef

	// Read value from the second address space
	set_asid(2);
	printf("A2 %08x\n", *((volatile unsigned int*) VADDR1)); // CHECK: A2 abcdefed

	return 0;
}
