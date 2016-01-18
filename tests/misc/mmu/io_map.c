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

//
// Ensure we are properly translating I/O addresses, specifically that
// we are using the physical address and not the virtual address to determine
// if something is in the I/O range.
// Map the I/O range at 1MB and the physical address 1MB into the virtual
// range 0xffff0000 (where I/O is physically located).
//

void printmsg(const char *value)
{
    const char *c;

    for (c = value; *c; c++)
        *((volatile unsigned int*) 0x100020) = *c;
}

int main(void)
{
    unsigned int va;
    unsigned int stack_addr = (unsigned int) &va & ~(PAGE_SIZE - 1);

    // Map code & data
    for (va = 0; va < 0x10000; va += PAGE_SIZE)
    {
        add_itlb_mapping(va, va | TLB_EXECUTABLE | TLB_PRESENT);
        add_dtlb_mapping(va, va | TLB_WRITABLE | TLB_PRESENT);
    }

    add_dtlb_mapping(stack_addr, stack_addr | TLB_PRESENT);

    // Map data where the I/O region normally goes
    add_dtlb_mapping(IO_REGION_BASE, 0x100000 | TLB_WRITABLE | TLB_PRESENT);

    // Map I/O region in different part of address space.
    add_dtlb_mapping(0x100000, IO_REGION_BASE | TLB_WRITABLE | TLB_PRESENT);

    // Enable MMU in flags register
    __builtin_nyuzi_write_control_reg(CR_FLAGS, FLAG_MMU_EN | FLAG_SUPERVISOR_EN);

    // Print a message
    printmsg("jabberwocky");

    // Copy into memory
    memcpy(IO_REGION_BASE, "galumphing", 10);
    asm("dflush %0" : : "s" (IO_REGION_BASE));

    // Since I/O is remapped, need to halt using new address
    *((volatile unsigned int*) 0x100064) = 1;

    return 0;
}
