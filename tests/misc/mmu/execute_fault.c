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

int main(void)
{
    map_program_and_stack();
    add_dtlb_mapping(IO_REGION_BASE, IO_REGION_BASE | TLB_WRITABLE
                     | TLB_PRESENT);

    // Add TLB mapping, but without executable bit
    add_itlb_mapping(TEST_CODE_SEG_BASE, TEST_CODE_SEG_BASE | TLB_PRESENT);
    *code_addr = INSTRUCTION_RET;
    asm volatile("membar");

    __builtin_nyuzi_write_control_reg(CR_FAULT_HANDLER, dump_fault_info);
    __builtin_nyuzi_write_control_reg(CR_FLAGS, FLAG_MMU_EN | FLAG_SUPERVISOR_EN);

    test_function();  // CHECK: FAULT 12 00109000 current flags 06 prev flags 06

    printf("should_not_be_here\n");
    // CHECKN: should_not_be_here
}

