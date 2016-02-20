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

// Test that writing to a supervisor page from user mode faults.

volatile unsigned int *data_addr = (unsigned int*) 0x100000;

void fault_handler()
{
    printf("FAULT %d %08x current flags %02x prev flags %02x\n",
           __builtin_nyuzi_read_control_reg(CR_FAULT_REASON),
           __builtin_nyuzi_read_control_reg(CR_FAULT_ADDRESS),
           __builtin_nyuzi_read_control_reg(CR_FLAGS),
           __builtin_nyuzi_read_control_reg(CR_SAVED_FLAGS));
    printf("data_addr = %08x", *data_addr);
    exit(0);
}

int main(void)
{
    int asid;

    map_program_and_stack();
    add_dtlb_mapping(IO_REGION_BASE, IO_REGION_BASE | TLB_WRITABLE
                     | TLB_PRESENT);

    // Data region marked supervisor.
    add_dtlb_mapping(data_addr, ((unsigned int) data_addr) | TLB_SUPERVISOR
                     | TLB_WRITABLE | TLB_PRESENT);

    *data_addr = 0x12345678;

    __builtin_nyuzi_write_control_reg(CR_FAULT_HANDLER, fault_handler);

    // Enable MMU and switch to user mode
    __builtin_nyuzi_write_control_reg(CR_FLAGS, FLAG_MMU_EN);

    // Flush pipeline
    usleep(0);

    // This write will fail. Ensure this raises a fault and that the memory
    // write failed.
    *data_addr = 0xdeadbeef;
    // CHECK: FAULT 8 00100000 current flags 06 prev flags 02
    // CHECK: data_addr = 12345678

    printf("should_not_be_here\n"); // CHECKN: should_not_be_here
}

