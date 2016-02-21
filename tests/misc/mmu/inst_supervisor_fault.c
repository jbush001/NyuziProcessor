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
#include "mmu_test_common.h"

// Test that supervisor bits work properly for ITLB entries: if the processor
// is in supervisor mode, it should be able to execute from pages with the
// supervisor bit set, but if it is in user mode, it should fault.

int main(void)
{
    unsigned int va;
    unsigned int stackAddr = (unsigned int) &va & ~(PAGE_SIZE - 1);

    // Map code & data
    for (va = 0; va < 0x10000; va += PAGE_SIZE)
    {
        addItlbMapping(va, va | TLB_SUPERVISOR | TLB_EXECUTABLE | TLB_PRESENT);
        addDtlbMapping(va, va | TLB_WRITABLE | TLB_SUPERVISOR | TLB_PRESENT);
    }

    addDtlbMapping(stackAddr, stackAddr | TLB_WRITABLE | TLB_PRESENT);
    addDtlbMapping(IO_REGION_BASE, IO_REGION_BASE | TLB_WRITABLE
                   | TLB_PRESENT);

    __builtin_nyuzi_write_control_reg(CR_FAULT_HANDLER, (unsigned int) dumpFaultInfo);

    // Enable MMU
    __builtin_nyuzi_write_control_reg(CR_FLAGS, FLAG_MMU_EN | FLAG_SUPERVISOR_EN);

    printf("one flags %02x prev flags %02x\n",
           __builtin_nyuzi_read_control_reg(CR_FLAGS),
           __builtin_nyuzi_read_control_reg(CR_SAVED_FLAGS)); // CHECK: one flags 06 prev flags 04

    // Switch to user mode, but leave MMU active
    switchToUserMode();

    // This will fault on instruction fetch.  Interrupts should be enabled, but
    // the processor should be back in supervisor mode. The string should not be
    // printed
    printf("THIS IS USER MODE\n");
    // CHECK: FAULT 9
    // CHECK: current flags 06 prev flags 02
    // CHECKN: THIS IS USER MODE
}

