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

// This does a lot of I/O writes while the timer interrupt is going off.
// There was a design issue where an interrupt coming during an I/O write
// could duplicate the write. This test ensures that doesn't happen.

#define CR_TRAP_HANDLER 1
#define CR_FLAGS 4
#define FLAG_INTERRUPT_EN (1 << 0)
#define FLAG_SUPERVISOR_EN (1 << 2)

extern void trap_handler();

// This is called by the low level trap_handler (in trap_handler.s)
// after it saves registers.
void do_trap(unsigned int *registers)
{
    printf("*");
}

int main(void)
{
    int i;

    __builtin_nyuzi_write_control_reg(CR_TRAP_HANDLER, trap_handler);
    __builtin_nyuzi_write_control_reg(CR_FLAGS, FLAG_INTERRUPT_EN | FLAG_SUPERVISOR_EN);

    printf(">ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789\n");

    return 0;
}

