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

//
// Test that illegal instructions generate traps
//

#include <stdint.h>

#define PTR_AS(num, type) *((type*) num)

extern void trap_handler();
extern void illegal_inst();

// This is called by the trap_handler shim in trap_handler.s after it saves
// registers
void do_trap(unsigned int *registers)
{
    printf("FAULT %d index %d\n", __builtin_nyuzi_read_control_reg(3),
           registers[10]);
    registers[31] += 4;	// Skip instruction
}

int main(int argc, const char *argv[])
{
    __builtin_nyuzi_write_control_reg(1, trap_handler);

    // This functions is in gen_illegal_inst_trap.S
    illegal_inst();

    printf("DONE\n"); // CHECK: DONE

    return 1;
}

