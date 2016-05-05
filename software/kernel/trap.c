//
// Copyright 2016 Jeff Bush
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

#include "asm.h"
#include "libc.h"

struct interrupt_frame
{
    unsigned int gpr[32];
    unsigned int flags;
    unsigned int subcycle;
};

void dumpTrap(const struct interrupt_frame*);

static const char *TRAP_NAMES[] = {
    "reset",
    "Illegal Instruction",
    "Data Alignment Fault",
    "Page Fault",
    "Instruction Alignment Fault",
    "ITLB Miss",
    "DTLB Miss",
    "Illegal Write",
    "Data Supervisor Fault",
    "Instruction Supervisor Fault",
    "Priveleged Operation",
    "Syscall",
    "Non Executable Page"
};

void handle_trap(struct interrupt_frame *frame)
{
    dumpTrap(frame);
}

void dumpTrap(const struct interrupt_frame *frame)
{
    int reg;
    int trapId = __builtin_nyuzi_read_control_reg(CR_TRAP_REASON);
    unsigned int trap_address = __builtin_nyuzi_read_control_reg(CR_TRAP_ADDR);

    if (trapId <= TR_NOT_EXECUTABLE)
    {
        kprintf("%s ", TRAP_NAMES[trapId]);
        if (trapId == TR_DATA_ALIGNMENT || trapId == TR_PAGE_FAULT
            || trapId == TR_ILLEGAL_WRITE || trapId == TR_DATA_SUPERVISOR)
        {
            kprintf("@%08x\n", trap_address);
        }
    }
    else
        kprintf("Unknown trap %d\n", trapId);

    kprintf("REGISTERS\n");
    for (reg = 0; reg < 32; reg++)
    {
        if (reg < 10)
            kprintf(" "); // Align single digit numbers

        kprintf("s%d %08x ", reg, frame->gpr[reg]);
        if (reg % 8 == 7)
            kprintf("\n");
    }

    kprintf("Flags: ");
    if (frame->flags & 1)
        kprintf("I");

    if (frame->flags & 2)
        kprintf("S");

    if (frame->flags & 4)
        kprintf("M");

    kprintf(" (%02x)\n\n", frame->flags);
    panic("HALT");
}
