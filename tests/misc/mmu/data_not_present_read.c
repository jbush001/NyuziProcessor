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

// Test that reading from a non-present data page faults

volatile unsigned int *data_addr = (volatile unsigned int*) 0x100000;

void fault_handler()
{
    printf("FAULT %d %08x current flags %02x prev flags %02x\n",
           __builtin_nyuzi_read_control_reg(CR_FAULT_REASON),
           __builtin_nyuzi_read_control_reg(CR_FAULT_ADDRESS),
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
        add_itlb_mapping(va, va | TLB_EXECUTABLE | TLB_PRESENT);
        add_dtlb_mapping(va, va | TLB_WRITABLE | TLB_GLOBAL | TLB_PRESENT);
    }

    add_dtlb_mapping(stack_addr, stack_addr | TLB_WRITABLE | TLB_PRESENT);
    add_dtlb_mapping(IO_REGION_BASE, IO_REGION_BASE | TLB_WRITABLE | TLB_PRESENT);

    // Data region that doesn't have the present bit set. This also has
    // a supervisor bit set, but the page fault should take priority.
    add_dtlb_mapping(data_addr, ((unsigned int)data_addr) | TLB_SUPERVISOR);

    __builtin_nyuzi_write_control_reg(CR_FAULT_HANDLER, fault_handler);
    __builtin_nyuzi_write_control_reg(CR_FLAGS, FLAG_MMU_EN);

    // Flush pipeline
    usleep(0);

    printf("read2 data_addr %08x\n", *data_addr);	// CHECK: FAULT 3 00100000 current flags 06 prev flags 02
    // CHECKN: read2 data_addr
}

