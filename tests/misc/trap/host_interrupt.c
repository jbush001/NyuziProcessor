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
#include <stdlib.h>

extern void trap_handler(void);

volatile int interruptCount = 0;

void do_trap(unsigned int *registers)
{
    printf("trap %02x\n", __builtin_nyuzi_read_control_reg(3));
    interruptCount++;
}

int main(void)
{
    __builtin_nyuzi_write_control_reg(1, trap_handler);
    __builtin_nyuzi_write_control_reg(4, 1); // Enable interrupts
    while (interruptCount < 5)
        ;

    // CHECK: trap 10
    // CHECK: trap 11
    // CHECK: trap 12
    // CHECK: trap 13
    // CHECK: trap 14

    // Check that this process is running correctly and interrupt
    // flag is cleared.
    printf("Back in main\n"); // CHECK: Back in main

    return 0;
}

