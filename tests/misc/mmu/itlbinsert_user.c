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

// Test that attempting to peform itlbinsert while in user mode raises a fault
// XXX Does not validate that the entry wasn't inserted.

int main(void)
{
    __builtin_nyuzi_write_control_reg(CR_FAULT_HANDLER, (unsigned int) dumpFaultInfo);

    // Switch to user mode, but leave MMU active
    switchToUserMode();

    asm("itlbinsert %0, %1" : : "r" (0), "r" (0));
    // CHECK: FAULT 10
    // CHECK: current flags 04 prev flags 00

    printf("should_not_be_here\n"); // CHECKN: should_not_be_here
}

