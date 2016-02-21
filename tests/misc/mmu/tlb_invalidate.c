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
// Check that tlbinval instruction will remove a TLB entry from DTLB by
// mapping a page, ensuring it can be accessed, invalidating, then
// attempting to access it again. The second access will raise a fault.
//

// Note: this aliases to virtual address. Ensure invalidate only removes the
// matching way.
volatile unsigned int *dataAddr = (unsigned int*) 0x100000;

int main(void)
{
    mapProgramAndStack();
    addDtlbMapping(IO_REGION_BASE, IO_REGION_BASE | TLB_WRITABLE
                   | TLB_PRESENT);

    addDtlbMapping((unsigned int) dataAddr, ((unsigned int)dataAddr) | TLB_WRITABLE
                   | TLB_PRESENT);

    // Enable MMU in flags register
    __builtin_nyuzi_write_control_reg(CR_TLB_MISS_HANDLER, (unsigned int) dumpFaultInfo);
    __builtin_nyuzi_write_control_reg(CR_FLAGS, FLAG_MMU_EN | FLAG_SUPERVISOR_EN);

    *dataAddr = 0x1f6818aa;
    printf("data value %08x\n", *dataAddr); // CHECK: data value 1f6818aa

    asm("tlbinval %0" : : "s" (dataAddr));

    printf("FAIL: read value %08x\n", *dataAddr);	// CHECK: FAULT 6 00100000
    // CHECKN: FAIL: read value

    return 0;
}
