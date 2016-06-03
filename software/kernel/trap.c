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
#include "thread.h"
#include "trap.h"
#include "vm_address_space.h"

struct interrupt_frame
{
    unsigned int gpr[32];
    unsigned int flags;
    unsigned int subcycle;
};

void dump_interrupt_frame(const struct interrupt_frame*);
extern int handle_syscall(int arg0, int arg1, int arg2, int arg3, int arg4,
                          int arg5);

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
    "Privileged Operation",
    "Syscall",
    "Non Executable Page"
};

static interrupt_handler_t handlers[NUM_INTERRUPTS];
static unsigned int enabled_interrupts;

// These are set by the user_copy routine.
unsigned int fault_handler[MAX_HW_THREADS];

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

static void __attribute__((noreturn)) bad_fault(struct interrupt_frame *frame)
{
    if (frame->flags & FLAG_SUPERVISOR_EN)
    {
        kprintf("Invalid kernel page fault thread %d\n", current_thread()->id);
        dump_interrupt_frame(frame);
        panic("stopping");
    }
    else
    {
        // User space crash. Kill thread. Should kill entire process,
        // but need signals/APCs to do that.
        kprintf("user space thread %d crashed\n", current_thread()->id);
        dump_interrupt_frame(frame);
        thread_exit(1);
    }
}

void handle_trap(struct interrupt_frame *frame)
{
    unsigned int address;
    int trapId = __builtin_nyuzi_read_control_reg(CR_TRAP_REASON);

    switch (trapId)
    {
        case TR_PAGE_FAULT:
            // Enable interrupts
            address = __builtin_nyuzi_read_control_reg(CR_TRAP_ADDR);
            __builtin_nyuzi_write_control_reg(CR_FLAGS,
                                              __builtin_nyuzi_read_control_reg(CR_FLAGS) | FLAG_INTERRUPT_EN);

            if (!handle_page_fault(address))
            {
                if (fault_handler[current_hw_thread()] != 0)
                {
                    // Jump to user_copy fault handler
                    frame->gpr[31] = fault_handler[current_hw_thread()];
                }
                else
                    bad_fault(frame);
            }

            // Disable interrupts
            __builtin_nyuzi_write_control_reg(CR_FLAGS,
                                              __builtin_nyuzi_read_control_reg(CR_FLAGS) & ~FLAG_INTERRUPT_EN);
            break;

        case TR_SYSCALL:
            // Enable interrupts
            address = __builtin_nyuzi_read_control_reg(CR_TRAP_ADDR);
            __builtin_nyuzi_write_control_reg(CR_FLAGS,
                                              __builtin_nyuzi_read_control_reg(CR_FLAGS) | FLAG_INTERRUPT_EN);

            frame->gpr[0] = handle_syscall(frame->gpr[0], frame->gpr[1],
                                           frame->gpr[2], frame->gpr[3],
                                           frame->gpr[4], frame->gpr[5]);

            frame->gpr[31] += 4;    // Next instruction

            // Disable interrupts
            __builtin_nyuzi_write_control_reg(CR_FLAGS,
                                              __builtin_nyuzi_read_control_reg(CR_FLAGS) & ~FLAG_INTERRUPT_EN);
            break;

        case TR_INTERRUPT:
            handle_interrupt(frame);
            break;

        default:
            bad_fault(frame);
    }
}

void dump_interrupt_frame(const struct interrupt_frame *frame)
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
        kprintf("M");

    if (frame->flags & 4)
        kprintf("S");

    kprintf(" (%02x)\n\n", frame->flags);
}
