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

// Check that the processor faults and doesn't update the TLB is
// dtlbinsert is called from user mode.

volatile unsigned int *data = 0x100000;

void tlb_fault_handler()
{
    printf("TLB fault\n");
    exit(1);
}

void general_fault_handler()
{
    printf("general fault %d\n", __builtin_nyuzi_read_control_reg(3));

    // Attempt to read from address that dtlbinsert was called on.
    // This should fault because TLB wasn't updated
    printf("FAIL: data is %08x\n", *data);
}

int main(void)
{
    unsigned int va;
    unsigned int stack_addr = (unsigned int) &va & ~(PAGE_SIZE - 1);

    // Map code & data
    for (va = 0; va < 0x10000; va += PAGE_SIZE)
    {
        add_itlb_mapping(va, va | TLB_PRESENT);
        add_dtlb_mapping(va, va | TLB_WRITABLE | TLB_PRESENT);
    }

    add_dtlb_mapping(stack_addr, stack_addr | TLB_WRITABLE | TLB_PRESENT);
    add_dtlb_mapping(IO_REGION_BASE, IO_REGION_BASE | TLB_WRITABLE | TLB_PRESENT);

    // Enable MMU and disable supervisor mode in flags register
    __builtin_nyuzi_write_control_reg(CR_FAULT_HANDLER, general_fault_handler);
    __builtin_nyuzi_write_control_reg(CR_TLB_MISS_HANDLER, tlb_fault_handler);
    __builtin_nyuzi_write_control_reg(CR_FLAGS, FLAG_MMU_EN);

    // This will fault because the thread is in user mode. Then the general
    // fault handler will read the address to ensure the mapping wasn't inserted.
    // That should cause a TLB fault.
    add_dtlb_mapping(data, ((unsigned int)data) | TLB_WRITABLE);
    // CHECK: general fault 10
    // CHECK: TLB fault

    printf("should_not_be_here\n"); // CHECKN: should_not_be_here
}

