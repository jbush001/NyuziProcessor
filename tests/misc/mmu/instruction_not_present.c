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

// Pick an address that will not alias to the existing code segment
#define TEST_CODE_SEG_BASE 0x109000

typedef void (*test_function_t)();

volatile unsigned int *code_addr = (volatile unsigned int*) TEST_CODE_SEG_BASE;
test_function_t test_function = (test_function_t) TEST_CODE_SEG_BASE;

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
        // Add not-present ITLB entry
        add_itlb_mapping(va, va | TLB_EXECUTABLE | TLB_GLOBAL | TLB_PRESENT);
        add_dtlb_mapping(va, va | TLB_WRITABLE | TLB_GLOBAL | TLB_PRESENT);
    }

    add_dtlb_mapping(stack_addr, stack_addr | TLB_WRITABLE | TLB_PRESENT);
    add_dtlb_mapping(IO_REGION_BASE, IO_REGION_BASE | TLB_WRITABLE
                     | TLB_PRESENT);

    // Add TLB mapping, but without present bit
    add_itlb_mapping(TEST_CODE_SEG_BASE, TEST_CODE_SEG_BASE | TLB_EXECUTABLE);
    *code_addr = INSTRUCTION_RET;
    asm volatile("membar");

    __builtin_nyuzi_write_control_reg(CR_FAULT_HANDLER, fault_handler);
    __builtin_nyuzi_write_control_reg(CR_FLAGS, FLAG_MMU_EN | FLAG_SUPERVISOR_EN);

    test_function();  // CHECK: FAULT 3 00109000 current flags 06 prev flags 06

    printf("should_not_be_here\n");
    // CHECKN: should_not_be_here
}

