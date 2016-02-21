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
// Ensure attempting to store to a page that does not have the write enable
// bit set will raise a fault and will not update the data in the page.
//

volatile unsigned int *dataAddr1 = (unsigned int*) 0x100000;
volatile unsigned int *dataAddr2 = (unsigned int*) 0x101000;

void faultHandler(void)
{
    printf("FAULT %d %08x\n", __builtin_nyuzi_read_control_reg(CR_FAULT_REASON),
           __builtin_nyuzi_read_control_reg(CR_FAULT_ADDRESS));
    printf("data value = %08x\n", dataAddr1[PAGE_SIZE / sizeof(int)]);
    exit(0);
}

int main(void)
{
    mapProgramAndStack();
    addDtlbMapping(IO_REGION_BASE, IO_REGION_BASE | TLB_WRITABLE
                   | TLB_PRESENT);

    addDtlbMapping((unsigned int) dataAddr1, ((unsigned int)dataAddr1) | TLB_WRITABLE
                   | TLB_PRESENT);	// Writable
    *dataAddr2 = 0x12345678;
    // This page is not writeable
    addDtlbMapping((unsigned int) dataAddr2, ((unsigned int) dataAddr2) | TLB_PRESENT);

    // Enable MMU in flags register
    __builtin_nyuzi_write_control_reg(CR_FAULT_HANDLER, (unsigned int) faultHandler);
    __builtin_nyuzi_write_control_reg(CR_TLB_MISS_HANDLER, (unsigned int) faultHandler);
    __builtin_nyuzi_write_control_reg(CR_FLAGS, FLAG_MMU_EN | FLAG_SUPERVISOR_EN);

    // This should write successfully
    *dataAddr1 = 0x1f6818aa;
    printf("data value %08x\n", *dataAddr1); // CHECK: data value 1f6818aa

    // Attempt to write to write protected page will fail.
    *dataAddr2 = 0xdeadbeef;

    // Ensure two things:
    // - that a fault is raised
    // - that the value isn't actually written
    // CHECK: FAULT 7 00101000
    // CHECK: data value = 12345678

    printf("should_not_be_here\n"); // CHECKN: should_not_be_here

    return 0;
}
