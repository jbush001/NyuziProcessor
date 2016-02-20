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

// This test allocates two address space identifiers, then adds a TLB
// entry for each. The two TLB entries have the same virtual address, but
// map to different physical addresses. This test checks that the entries
// map correctly. It also validates that the global TLB bit is observed
// and those entries appear in both address spaces.
//

// Virtual addresses are chosen to not alias with code or other pages
#define VADDR1 0x10a000
#define PADDR1 0x100000
#define PADDR2 0x101000

int main(void)
{
    int asid;

    map_program_and_stack();
    add_dtlb_mapping(IO_REGION_BASE, IO_REGION_BASE | TLB_WRITABLE
                     | TLB_GLOBAL | TLB_PRESENT);

    // Map a private page into address space 1
    set_asid(1);
    add_dtlb_mapping(VADDR1, PADDR1 | TLB_PRESENT);
    *((unsigned int*) PADDR1) = 0xdeadbeef;

    // Map a private page into address space 2
    set_asid(2);
    add_dtlb_mapping(VADDR1, PADDR2 | TLB_PRESENT);
    *((unsigned int*) PADDR2) = 0xabcdefed;

    // Enable MMU in flags register
    __builtin_nyuzi_write_control_reg(CR_FAULT_HANDLER, dump_fault_info);
    __builtin_nyuzi_write_control_reg(CR_TLB_MISS_HANDLER, dump_fault_info);
    __builtin_nyuzi_write_control_reg(CR_FLAGS, FLAG_MMU_EN | FLAG_SUPERVISOR_EN);

    // Read value from first address space
    set_asid(1);
    printf("A1 %08x\n", *((volatile unsigned int*) VADDR1)); // CHECK: A1 deadbeef

    // Read value from the second address space
    set_asid(2);
    printf("A2 %08x\n", *((volatile unsigned int*) VADDR1)); // CHECK: A2 abcdefed

    return 0;
}
