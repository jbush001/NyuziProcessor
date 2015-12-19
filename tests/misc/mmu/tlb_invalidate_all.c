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

//
// Ensure the tlbinvalall instruction invalidates TLB entries
// XXX I can't check that all entries are missing, just that tlbinvalall removed
// at least the next page I attempted to access
//

void tlb_miss_handler()
{
	printf("TLB miss\n");
	exit(0);
}

int main(void)
{
	unsigned int va;
	unsigned int stack_addr = (unsigned int) &va & ~(PAGE_SIZE - 1);

	// Map code & data
	for (va = 0; va < 0x10000; va += PAGE_SIZE)
	{
		add_itlb_mapping(va, va);
		add_dtlb_mapping(va, va | TLB_WRITABLE);
	}

	add_dtlb_mapping(stack_addr, stack_addr | TLB_WRITABLE);
	add_dtlb_mapping(IO_REGION_BASE, IO_REGION_BASE | TLB_WRITABLE);

	// Enable MMU in flags register
	__builtin_nyuzi_write_control_reg(CR_TLB_MISS_HANDLER, tlb_miss_handler);
	__builtin_nyuzi_write_control_reg(CR_FLAGS, FLAG_MMU_EN | FLAG_SUPERVISOR_EN);

	printf("Working correctly so far\n"); // CHECK: Working correctly so far

	asm("tlbinvalall");

	printf("FAIL: should have faulted\n");	// CHECK: TLB miss

	return 0;
}
