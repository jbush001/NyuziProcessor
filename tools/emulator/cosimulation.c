//
// Copyright 2011-2015 Jeff Bush
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

#include <stdbool.h>
#include <stdio.h>
#include <string.h>
#include "processor.h"
#include "cosimulation.h"
#include "inttypes.h"
#include "util.h"

//
// Cosimulation runs as follows:
// 1. The main loop (run_cosimulation) reads and parses the next instruction
//    side effect from the Verilator model (piped to this process via stdin).
//    It stores the value in the expected_xXX global variables.
// 2. It then calls run_until_next_event, which calls into the emulator core to
//    single step until...
// 3. When the emulator core updates a register or performs a memory write,
//    it calls back into this module, one of the cosim_check_xXX functions.
//    The check functions compare the local side effect to the values saved
//    by step 1. If there is a mismatch, they flag an error, otherwise...
// 4. Loop back to step 1
//

static void print_cosim_expected(void);
static bool run_until_next_event(struct processor*, uint32_t thread_id);
static bool masked_vectors_equal(uint32_t mask, const uint32_t *values1, const uint32_t *values2);

static enum
{
    EVENT_NONE,
    EVENT_MEM_STORE,
    EVENT_VECTOR_WRITEBACK,
    EVENT_SCALAR_WRITEBACK
} expected_event;
static uint32_t expected_register;
static uint32_t expected_address;
static uint64_t expected_mask;
static uint32_t expected_values[NUM_VECTOR_LANES];
static uint32_t expected_pc;
static uint32_t expected_thread;
static bool cosim_mismatch;
static bool cosim_event_triggered;

// Read events from standard in.  Step each emulator thread in lockstep
// and ensure the side effects match.
int run_cosimulation(struct processor *proc, bool verbose)
{
    char line[1024];
    uint32_t thread_id;
    uint32_t address;
    uint32_t pc;
    uint64_t write_mask;
    uint32_t vector_values[NUM_VECTOR_LANES];
    char value_str[256];
    uint32_t reg;
    uint32_t scalar_value;
    bool verilog_model_halted = false;
    size_t len;

    enable_cosimulation(proc);
    if (verbose)
        enable_tracing(proc);

    while (fgets(line, sizeof(line), stdin))
    {
        if (verbose)
            printf("%s", line);

        len = strlen(line);
        if (len > 0)
            line[len - 1] = '\0';	// Strip off newline

        if (sscanf(line, "store %x %x %x %" PRIx64 " %s", &pc, &thread_id, &address, &write_mask, value_str) == 5)
        {
            // Memory Store
            if (parse_hex_vector(value_str, vector_values, true) < 0)
            {
                printf("Error parsing cosimulation event\n");
                return -1;
            }

            expected_event = EVENT_MEM_STORE;
            expected_pc = pc;
            expected_thread = thread_id;
            expected_address = address;
            expected_mask = write_mask;
            memcpy(expected_values, vector_values, sizeof(uint32_t) * NUM_VECTOR_LANES);
            if (!run_until_next_event(proc, thread_id))
                return -1;
        }
        else if (sscanf(line, "vwriteback %x %x %x %" PRIx64 " %s", &pc, &thread_id, &reg, &write_mask, value_str) == 5)
        {
            // Vector writeback
            if (parse_hex_vector(value_str, vector_values, false) < 0)
            {
                printf("Error parsing cosimulation event\n");
                return -1;
            }

            expected_event = EVENT_VECTOR_WRITEBACK;
            expected_pc = pc;
            expected_thread = thread_id;
            expected_register = reg;
            expected_mask = write_mask;
            memcpy(expected_values, vector_values, sizeof(uint32_t) * NUM_VECTOR_LANES);
            if (!run_until_next_event(proc, thread_id))
                return -1;
        }
        else if (sscanf(line, "swriteback %x %x %x %x", &pc, &thread_id, &reg, &scalar_value) == 4)
        {
            // Scalar Writeback
            expected_event = EVENT_SCALAR_WRITEBACK;
            expected_pc = pc;
            expected_thread = thread_id;
            expected_register = reg;
            expected_values[0] = scalar_value;
            if (!run_until_next_event(proc, thread_id))
                return -1;
        }
        else if (strcmp(line, "***HALTED***") == 0)
        {
            verilog_model_halted = true;
            break;
        }
        else if (sscanf(line, "interrupt %u %x", &thread_id, &pc) == 2)
            cosim_interrupt(proc, thread_id, pc);
        else if (!verbose)
            printf("%s\n", line);	// Echo unrecognized lines to stdout (verbose already does this for all lines)
    }

    if (!verilog_model_halted)
    {
        printf("program did not finish normally\n");
        printf("%s\n", line);	// Print error (if any)
        return -1;
    }

    // Ensure emulator is also halted. If it executes any more instructions
    // cosim_mismatch will be flagged.
    cosim_event_triggered = false;
    expected_event = EVENT_NONE;
    while (!is_proc_halted(proc))
    {
        execute_instructions(proc, ALL_THREADS, 1);
        if (cosim_mismatch)
            return -1;
    }

    return 0;
}

void cosim_check_set_scalar_reg(struct processor *proc, uint32_t pc, uint32_t reg, uint32_t value)
{
    cosim_event_triggered = true;
    if (expected_event != EVENT_SCALAR_WRITEBACK
            || expected_pc != pc
            || expected_register != reg
            || expected_values[0] != value)
    {
        cosim_mismatch = true;
        print_registers(proc, expected_thread);
        printf("COSIM MISMATCH, thread %d\n", expected_thread);
        printf("Reference: %08x s%d <= %08x\n", pc, reg, value);
        printf("Hardware:  ");
        print_cosim_expected();
        return;
    }
}

void cosim_check_set_vector_reg(struct processor *proc, uint32_t pc, uint32_t reg, uint32_t mask,
                                const uint32_t *values)
{
    int lane;

    cosim_event_triggered = true;
    if (expected_event != EVENT_VECTOR_WRITEBACK
            || expected_pc != pc
            || expected_register != reg
            || !masked_vectors_equal(mask, expected_values, values)
            || expected_mask != (mask & 0xffff))
    {
        cosim_mismatch = true;
        print_registers(proc, expected_thread);
        printf("COSIM MISMATCH, thread %d\n", expected_thread);
        printf("Reference: %08x v%d{%04x} <= ", pc, reg, mask & 0xffff);
        for (lane = 0; lane < NUM_VECTOR_LANES; lane++)
            printf("%08x ", values[lane]);

        printf("\n");
        printf("Hardware:  ");
        print_cosim_expected();
        return;
    }
}

void cosim_check_vector_store(struct processor *proc, uint32_t pc, uint32_t address, uint32_t mask,
                              const uint32_t *values)
{
    uint64_t byte_mask;
    int lane;

    byte_mask = 0;
    for (lane = 0; lane < NUM_VECTOR_LANES; lane++)
    {
        if (mask & (1 << lane))
            byte_mask |= 0xf000000000000000ull >> (lane * 4);
    }

    cosim_event_triggered = true;
    if (expected_event != EVENT_MEM_STORE
            || expected_pc != pc
            || expected_address != (address & ~(NUM_VECTOR_LANES * 4u - 1))
            || expected_mask != byte_mask
            || !masked_vectors_equal(mask, expected_values, values))
    {
        cosim_mismatch = true;
        print_registers(proc, expected_thread);
        printf("COSIM MISMATCH, thread %d\n", expected_thread);
        printf("Reference: %08x memory[%x]{%016" PRIx64 "} <= ", pc, address, byte_mask);
        for (lane = 0; lane < NUM_VECTOR_LANES; lane++)
            printf("%08x ", values[lane]);

        printf("\n_hardware:  ");
        print_cosim_expected();
        return;
    }
}

void cosim_check_scalar_store(struct processor *proc, uint32_t pc, uint32_t address, uint32_t size,
                              uint32_t value)
{
    uint32_t hardware_value;
    uint64_t reference_mask;

    hardware_value = expected_values[(address & CACHE_LINE_MASK) / 4];
    if (size < 4)
    {
        uint32_t mask = (1 << (size * 8)) - 1;
        hardware_value &= mask;
        value &= mask;
    }

    reference_mask = ((1ull << size) - 1ull) << (CACHE_LINE_MASK - (address & CACHE_LINE_MASK) - (size - 1));
    cosim_event_triggered = true;
    if (expected_event != EVENT_MEM_STORE
            || expected_pc != pc
            || expected_address != (address & ~CACHE_LINE_MASK)
            || expected_mask != reference_mask
            || hardware_value != value)
    {
        cosim_mismatch = true;
        print_registers(proc, expected_thread);
        printf("COSIM MISMATCH, thread %d\n", expected_thread);
        printf("Reference: %08x memory[%x]{%016" PRIx64 "} <= %08x\n", pc, address & ~CACHE_LINE_MASK,
               reference_mask, value);
        printf("Hardware:  ");
        print_cosim_expected();
        return;
    }
}

static void print_cosim_expected(void)
{
    int lane;

    printf("%08x ", expected_pc);

    switch (expected_event)
    {
        case EVENT_NONE:
            printf(" HALTED\n");
            break;

        case EVENT_MEM_STORE:
            printf("memory[%x]{%016" PRIx64 "} <= ", expected_address, expected_mask);
            for (lane = 0; lane < NUM_VECTOR_LANES; lane++)
                printf("%08x ", expected_values[lane]);

            printf("\n");
            break;

        case EVENT_VECTOR_WRITEBACK:
            printf("v%d{%04x} <= ", expected_register, (uint32_t)
                   expected_mask & 0xffff);
            for (lane = 0; lane < NUM_VECTOR_LANES; lane++)
                printf("%08x ", expected_values[lane]);

            printf("\n");
            break;

        case EVENT_SCALAR_WRITEBACK:
            printf("s%d <= %08x\n", expected_register, expected_values[0]);
            break;
    }
}

// Returns true if the event matched, false if it did not.
static bool run_until_next_event(struct processor *proc, uint32_t thread_id)
{
    int count = 0;

    cosim_mismatch = false;
    cosim_event_triggered = false;
    for (count = 0; count < 500 && !cosim_event_triggered; count++)
        dbg_single_step(proc, thread_id);

    if (!cosim_event_triggered)
    {
        printf("Simulator program in infinite loop? No event occurred.  Was expecting:\n");
        print_cosim_expected();
    }

    return cosim_event_triggered && !cosim_mismatch;
}

// Returns 1 if the masked values match, 0 otherwise
static bool masked_vectors_equal(uint32_t mask, const uint32_t *values1, const uint32_t *values2)
{
    int lane;

    for (lane = 0; lane < NUM_VECTOR_LANES; lane++)
    {
        if (mask & (1 << lane))
        {
            if (values1[lane] != values2[lane])
                return false;
        }
    }

    return true;
}
