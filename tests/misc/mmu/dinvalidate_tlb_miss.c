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
#include "mmu_test_common.h"

#define DATA_BASE 0x100000

//
// Ensure dinvalidate will cause a TLB miss if there isn't
// a mapping.
//

void tlb_miss_handler()
{
    printf("FAULT %d %08x\n", __builtin_nyuzi_read_control_reg(CR_FAULT_REASON),
           __builtin_nyuzi_read_control_reg(CR_FAULT_ADDRESS));
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
    add_dtlb_mapping(DATA_BASE, DATA_BASE | TLB_WRITABLE);
    add_dtlb_mapping(IO_REGION_BASE, IO_REGION_BASE | TLB_WRITABLE);

    // Set up miss handler
    __builtin_nyuzi_write_control_reg(CR_TLB_MISS_HANDLER, tlb_miss_handler);
    __builtin_nyuzi_write_control_reg(CR_FLAGS, FLAG_MMU_EN | FLAG_SUPERVISOR_EN);

    // This dinvalidate should already be present (invalidate will remove the
    // cache line, but not the TLB mapping)
    asm("dinvalidate %0" : : "s" (DATA_BASE));

    printf("FLUSH1\n");	// CHECK: FLUSH1

    // This dinvalidate should cause a TLB miss
    asm("dinvalidate %0" : : "s" (DATA_BASE + PAGE_SIZE)); // CHECK: FAULT 6 00101000

    printf("should_not_be_here\n"); // CHECKN: should_not_be_here

    return 0;
}
