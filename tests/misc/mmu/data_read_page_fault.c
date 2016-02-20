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

int main(void)
{
    map_program_and_stack();
    add_dtlb_mapping(IO_REGION_BASE, IO_REGION_BASE | TLB_WRITABLE
                     | TLB_PRESENT);

    // Data region that doesn't have the present bit set.
    add_dtlb_mapping(data_addr, ((unsigned int)data_addr));

    __builtin_nyuzi_write_control_reg(CR_FAULT_HANDLER, dump_fault_info);
    __builtin_nyuzi_write_control_reg(CR_FLAGS, FLAG_MMU_EN);

    // Flush pipeline
    usleep(0);

    printf("read2 data_addr %08x\n", *data_addr);	// CHECK: FAULT 3 00100000 current flags 06 prev flags 02
    // CHECKN: read2 data_addr
}

