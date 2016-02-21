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

// Test that reading from a supervisor page from user mode faults.

volatile unsigned int *dataAddr = (volatile unsigned int*) 0x100000;

int main(void)
{
    mapProgramAndStack();
    addDtlbMapping(IO_REGION_BASE, IO_REGION_BASE | TLB_WRITABLE
                   | TLB_PRESENT);

    // Data region marked supervisor
    addDtlbMapping((unsigned int) dataAddr, ((unsigned int) dataAddr) | TLB_SUPERVISOR
                   | TLB_WRITABLE | TLB_PRESENT);

    __builtin_nyuzi_write_control_reg(CR_FAULT_HANDLER, (unsigned int) dumpFaultInfo);
    __builtin_nyuzi_write_control_reg(CR_FLAGS, FLAG_MMU_EN | FLAG_SUPERVISOR_EN);

    // We are currently in supervisor mode. write then read to the page
    *dataAddr = 0x12345678;
    printf("read1 dataAddr %08x\n", *dataAddr);	// CHECK: read1 dataAddr 12345678

    // Switch to user mode, but leave MMU active
    switchToUserMode();

    printf("read2 dataAddr %08x\n", *dataAddr);	// CHECK: FAULT 8 00100000 current flags 06 prev flags 02
    // CHECKN: read2 dataAddr
}

