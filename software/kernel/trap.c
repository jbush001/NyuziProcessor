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
#include "registers.h"
#include "trap.h"

struct interrupt_frame
{
    unsigned int gpr[32];
    unsigned int flags;
    unsigned int subcycle;
};

void dumpTrap(const struct interrupt_frame*);

static const char *TRAP_NAMES[] =
{
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

static interrupt_handler_t handlers[NUM_INTERRUPTS];
static unsigned int enabled_interrupts;

void handle_syscall(struct interrupt_frame *frame)
{
    switch (frame->gpr[0])
    {
        case 7: // Print something
            // !!! Needs to do copy from user. Unsafe.
            kprintf("%s", frame->gpr[1]);
            break;

        default:
            kprintf("Unknown syscall %d\n", frame->gpr[0]);
    }

    frame->gpr[31] += 4;    // Next instruction
}

void register_interrupt_handler(int interrupt, interrupt_handler_t handler)
{
    // XXX lock
    handlers[interrupt] = handler;
    enabled_interrupts |= 1 << interrupt;
    REGISTERS[REG_INT_MASK0] = enabled_interrupts;
}

static void handle_interrupt(struct interrupt_frame *frame)
{
    unsigned int interrupt_bitmap = REGISTERS[REG_PENDING_INTERRUPT]
                                    & enabled_interrupts;
    while (interrupt_bitmap)
    {
        int next_int = __builtin_ctz(interrupt_bitmap);
        interrupt_bitmap &= ~(1 << next_int);
        if (handlers[next_int] == 0)
        {
            kprintf("No handler for interrupt %d", next_int);
            panic("STOPPING");
        }

        (*handlers[next_int])();
    }
}

void ack_interrupt(int interrupt)
{
    REGISTERS[REG_ACK_INTERRUPT] = 1 << interrupt;
}

void handle_trap(struct interrupt_frame *frame)
{
    int trapId = __builtin_nyuzi_read_control_reg(CR_TRAP_REASON);
    switch (trapId)
    {
        case TR_SYSCALL:
            handle_syscall(frame);
            break;

        case TR_INTERRUPT:
            handle_interrupt(frame);
            break;

        default:
            dumpTrap(frame);
            panic("Unhandled trap");
    }
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
