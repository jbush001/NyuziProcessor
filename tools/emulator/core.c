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

#include <assert.h>
#include <fcntl.h>
#include <inttypes.h>
#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/mman.h>
#include <sys/time.h>
#include <sys/types.h>
#include <time.h>
#include <unistd.h>
#include "core.h"
#include "cosimulation.h"
#include "device.h"
#include "instruction-set.h"
#include "util.h"

#define TLB_SETS 16
#define TLB_WAYS 4
#define PAGE_SIZE 0x1000u
#define ROUND_TO_PAGE(addr) ((addr) & ~(PAGE_SIZE - 1u))
#define PAGE_OFFSET(addr) ((addr) & (PAGE_SIZE - 1u))
#define TRAP_LEVELS 2

#ifdef DUMP_INSTRUCTION_STATS
#define TALLY_INSTRUCTION(type) thread->core->stat ## type++
#else
#define TALLY_INSTRUCTION(type) do { } while (0)
#endif

#define INVALID_ADDR 0xfffffffful


// When a breakpoint is set, this instruction replaces the one at the
// breakpoint address. It is invalid, because it uses a reserved format
// type. The interpreter only performs a breakpoint lookup when it sees
// this instruction as an optimization.
#define BREAKPOINT_INST 0x707fffff

struct thread
{
    struct core *core;
    uint32_t id;
    uint32_t last_sync_load_addr; // Cache line number (addr / 64)
    uint32_t pc;
    uint32_t asid;
    uint32_t page_dir;
    uint32_t interrupt_mask;
    uint32_t pending_interrupts;
    bool enable_interrupt;
    bool enable_mmu;
    bool enable_supervisor;
    uint32_t subcycle;
    uint32_t scalar_reg[NUM_REGISTERS - 1];	// PC (31) not included here
    uint32_t vector_reg[NUM_REGISTERS][NUM_VECTOR_LANES];
    bool interrupt_pending;

    // There are two levels of trap information, to handle a nested TLB
    // miss occurring in the middle of another trap.
    struct
    {
        uint32_t trap_cause;
        uint32_t pc;
        uint32_t access_address;
        uint32_t scratchpad0;
        uint32_t scratchpad1;
        uint32_t subcycle;
        bool enable_interrupt;
        bool enable_mmu;
        bool enable_supervisor;
    } saved_trap_state[TRAP_LEVELS];
};

struct tlb_entry
{
    uint32_t asid;
    uint32_t virtual_address;
    uint32_t phys_addr_and_flags;
};

struct core
{
    struct thread *threads;
    struct breakpoint *breakpoints;
    uint32_t *memory;
    uint32_t memory_size;
    uint32_t total_threads;
    uint32_t thread_enable_mask;
    uint32_t trap_handler_pc;
    uint32_t tlb_miss_handler_pc;
    uint32_t phys_tlb_update_addr;
    struct tlb_entry *itlb;
    uint32_t next_itlb_way;
    struct tlb_entry *dtlb;
    uint32_t next_dtlb_way;
    bool crashed;
    bool single_stepping;
    bool stop_on_fault;
    bool enable_tracing;
    bool enable_cosim;
    uint32_t current_timer_count;
    int64_t total_instructions;
    uint32_t start_cycle_count;
#ifdef DUMP_INSTRUCTION_STATS
    int64_t stat_vector_inst;
    int64_t stat_load_inst;
    int64_t stat_store_inst;
    int64_t stat_branch_inst;
    int64_t stat_imm_arith_inst;
    int64_t stat_reg_arith_inst;
#endif
};

struct breakpoint
{
    struct breakpoint *next;
    uint32_t address;
    uint32_t original_instruction;
    bool restart;
};

static void print_thread_registers(const struct thread*);
static uint32_t get_thread_scalar_reg(const struct thread*, uint32_t reg);
static void set_scalar_reg(struct thread*, uint32_t reg, uint32_t value);
static void set_vector_reg(struct thread*, uint32_t reg, uint32_t mask,
                           uint32_t *values);
static void invalidate_sync_address(struct core*, uint32_t address);
static void try_to_dispatch_interrupt(struct thread*);
static void raise_trap(struct thread*, uint32_t address, enum trap_type type, bool is_store,
                       bool is_data_cache);
static bool translate_address(struct thread*, uint32_t virtual_address, uint32_t
                              *physical_address, bool is_store, bool is_data_cache);
static uint32_t scalar_arithmetic_op(enum arithmetic_op, uint32_t value1, uint32_t value2);
static bool is_compare_op(uint32_t op);
static struct breakpoint *lookup_breakpoint(struct core*, uint32_t pc);
static void execute_register_arith_inst(struct thread*, uint32_t instruction);
static void execute_immediate_arith_inst(struct thread*, uint32_t instruction);
static void execute_scalar_load_store_inst(struct thread*, uint32_t instruction);
static void execute_block_load_store_inst(struct thread*, uint32_t instruction);
static void execute_scatter_gather_inst(struct thread*, uint32_t instruction);
static void execute_control_register_inst(struct thread*, uint32_t instruction);
static void execute_memory_access_inst(struct thread*, uint32_t instruction);
static void execute_branch_inst(struct thread*, uint32_t instruction);
static void execute_cache_control_inst(struct thread*, uint32_t instruction);
static bool execute_instruction(struct thread*);
static void timer_tick(struct core *core);

struct core *init_core(uint32_t memory_size, uint32_t total_threads, bool randomize_memory,
                       const char *shared_memory_file)
{
    uint32_t address;
    uint32_t threadid;
    struct core *core;
    int i;
    struct timeval tv;
    int shared_memory_fd;

    // Limited by enable mask
    assert(total_threads <= 32);

    core = (struct core*) calloc(sizeof(struct core), 1);
    core->memory_size = memory_size;
    if (shared_memory_file != NULL)
    {
        shared_memory_fd = open(shared_memory_file, O_CREAT | O_RDWR, 666);
        if (shared_memory_fd < 0)
        {
            perror("init_core: Error opening shared memory file");
            return NULL;
        }

        if (ftruncate(shared_memory_fd, memory_size) < 0)
        {
            perror("init_core: couldn't resize shared memory file");
            return NULL;
        }

        core->memory = mmap(NULL, memory_size, PROT_READ | PROT_WRITE, MAP_SHARED
                            | MAP_FILE, shared_memory_fd, 0);
        if (core->memory == NULL)
        {
            perror("init_core: mmap failed");
            return NULL;
        }
    }
    else
    {
        core->memory = (uint32_t*) malloc(memory_size);
        if (core->memory == NULL)
        {
            perror("init_core: malloc failed");
            return NULL;
        }

        if (randomize_memory)
        {
            srand((unsigned int) time(NULL));
            for (address = 0; address < memory_size / 4; address++)
                core->memory[address] = (uint32_t) rand();
        }
        else
            memset(core->memory, 0, core->memory_size);
    }

    core->itlb = (struct tlb_entry*) malloc(sizeof(struct tlb_entry) * TLB_SETS * TLB_WAYS);
    core->dtlb = (struct tlb_entry*) malloc(sizeof(struct tlb_entry) * TLB_SETS * TLB_WAYS);
    for (i = 0; i < TLB_SETS * TLB_WAYS; i++)
    {
        // Set to invalid (unaligned) addresses so these don't match
        core->itlb[i].virtual_address = INVALID_ADDR;
        core->dtlb[i].virtual_address = INVALID_ADDR;
    }

    core->total_threads = total_threads;
    core->threads = (struct thread*) calloc(sizeof(struct thread), total_threads);
    for (threadid = 0; threadid < total_threads; threadid++)
    {
        core->threads[threadid].core = core;
        core->threads[threadid].id = threadid;
        core->threads[threadid].last_sync_load_addr = INVALID_ADDR;
        core->threads[threadid].enable_supervisor = true;
        core->threads[threadid].saved_trap_state[0].enable_supervisor = true;
    }

    core->thread_enable_mask = 1;
    core->crashed = false;
    core->enable_tracing = false;
    core->trap_handler_pc = 0;

    gettimeofday(&tv, NULL);
    core->start_cycle_count = (uint32_t)(tv.tv_sec * 50000000 + tv.tv_usec * 50);

    return core;
}

void enable_tracing(struct core *core)
{
    core->enable_tracing = true;
}

int load_hex_file(struct core *core, const char *filename)
{
    FILE *file;
    char line[16];
    uint32_t *memptr = core->memory;

    file = fopen(filename, "r");
    if (file == NULL)
    {
        perror("load_hex_file: error opening hex file");
        return -1;
    }

    while (fgets(line, sizeof(line), file))
    {
        *memptr++ = endian_swap32((uint32_t) strtoul(line, NULL, 16));
        if ((uint32_t)((memptr - core->memory) * 4) >= core->memory_size)
        {
            fprintf(stderr, "load_hex_file: hex file too big to fit in memory\n");
            return -1;
        }
    }

    fclose(file);

    return 0;
}

void write_memory_to_file(const struct core *core, const char *filename, uint32_t base_address,
                          uint32_t length)
{
    FILE *file;

    file = fopen(filename, "wb+");
    if (file == NULL)
    {
        perror("write_memory_to_file: Error opening output file");
        return;
    }

    if (fwrite((int8_t*) core->memory + base_address, MIN(core->memory_size, length), 1, file) <= 0)
    {
        perror("write_memory_to_file: fwrite failed");
        return;
    }

    fclose(file);
}

const void *get_memory_region_ptr(const struct core *core, uint32_t address, uint32_t length)
{
    assert(length < core->memory_size);

    // Prevent overrun for bad address
    if (address > core->memory_size || address + length > core->memory_size)
        return core->memory;

    return ((const uint8_t*) core->memory) + address;
}

void print_registers(const struct core *core, uint32_t thread_id)
{
    print_thread_registers(&core->threads[thread_id]);
}

void enable_cosimulation(struct core *core)
{
    core->enable_cosim = true;
}

void raise_interrupt(struct core *core, uint32_t int_bitmap)
{
    uint32_t thread_id;

    for (thread_id = 0; thread_id < core->total_threads; thread_id++)
    {
        core->threads[thread_id].pending_interrupts |= int_bitmap;
        try_to_dispatch_interrupt(&core->threads[thread_id]);
    }
}

// Called when the verilog model in cosimulation indicates an interrupt.
void cosim_interrupt(struct core *core, uint32_t thread_id, uint32_t pc)
{
    struct thread *thread = &core->threads[thread_id];

    // This handles an edge case where cosimulation mismatches would occur
    // if an interrupt happened during a scatter store. Hardware does not
    // create store cycles for scatter store lanes that do not have the mask
    // bit set (and thus doesn't emit cosimulation events). It's possible for
    // the instruction to finish in hardware, but the emulator not to have
    // finished it. When it starts executing the ISR, the subcycle counter
    // will be non-zero, which messes up things later.
    if (pc != thread->pc)
        thread->subcycle = 0;

    thread->pc = pc;
    thread->pending_interrupts |= INT_COSIM;
    try_to_dispatch_interrupt(thread);
}

uint32_t get_total_threads(const struct core *core)
{
    return core->total_threads;
}

bool core_halted(const struct core *core)
{
    return core->thread_enable_mask == 0 || core->crashed;
}

bool stopped_on_fault(const struct core *core)
{
    return core->crashed;
}

bool execute_instructions(struct core *core, uint32_t thread_id, uint64_t total_instructions)
{
    uint64_t instruction_count;
    uint32_t thread;

    core->single_stepping = false;
    for (instruction_count = 0; instruction_count < total_instructions; instruction_count++)
    {
        if (core->thread_enable_mask == 0)
        {
            printf("struct thread enable mask is now zero\n");
            return false;
        }

        if (core->crashed)
            return false;

        if (thread_id == ALL_THREADS)
        {
            // Cycle through threads round-robin
            for (thread = 0; thread < core->total_threads; thread++)
            {
                if (core->thread_enable_mask & (1 << thread))
                {
                    if (!execute_instruction(&core->threads[thread]))
                        return false;  // Hit breakpoint
                }
            }
        }
        else
        {
            if (!execute_instruction(&core->threads[thread_id]))
                return false;  // Hit breakpoint
        }

        timer_tick(core);
    }

    return true;
}

void single_step(struct core *core, uint32_t thread_id)
{
    core->single_stepping = true;
    execute_instruction(&core->threads[thread_id]);
    timer_tick(core);
}

uint32_t get_pc(const struct core *core, uint32_t thread_id)
{
    return core->threads[thread_id].pc;
}

uint32_t get_scalar_register(const struct core *core, uint32_t thread_id, uint32_t reg_id)
{
    return get_thread_scalar_reg(&core->threads[thread_id], reg_id);
}

uint32_t get_vector_register(const struct core *core, uint32_t thread_id, uint32_t reg_id, uint32_t lane)
{
    return core->threads[thread_id].vector_reg[reg_id][lane];
}

uint32_t debug_read_memory_byte(const struct core *core, uint32_t address)
{
    return ((uint8_t*)core->memory)[address];
}

void debug_write_memory_byte(const struct core *core, uint32_t address, uint8_t byte)
{
    ((uint8_t*)core->memory)[address] = byte;
}

int set_breakpoint(struct core *core, uint32_t pc)
{
    struct breakpoint *breakpoint = lookup_breakpoint(core, pc);
    if (breakpoint != NULL)
    {
        printf("already has a breakpoint at address %x\n", pc);
        return -1;
    }

    if (pc >= core->memory_size || (pc & 3) != 0)
    {
        printf("invalid breakpoint address %x\n", pc);
        return -1;
    }

    breakpoint = (struct breakpoint*) calloc(sizeof(struct breakpoint), 1);
    breakpoint->next = core->breakpoints;
    core->breakpoints = breakpoint;
    breakpoint->address = pc;
    breakpoint->original_instruction = core->memory[pc / 4];
    if (breakpoint->original_instruction == BREAKPOINT_INST)
        breakpoint->original_instruction = INSTRUCTION_NOP;	// Avoid infinite loop

    core->memory[pc / 4] = BREAKPOINT_INST;
    return 0;
}

int clear_breakpoint(struct core *core, uint32_t pc)
{
    struct breakpoint **link;

    for (link = &core->breakpoints; *link; link = &(*link)->next)
    {
        if ((*link)->address == pc)
        {
            core->memory[pc / 4] = (*link)->original_instruction;
            *link = (*link)->next;
            return 0;
        }
    }

    return -1; // Not found
}

void set_stop_on_fault(struct core *core, bool stop_on_fault)
{
    core->stop_on_fault = stop_on_fault;
}

void dump_instruction_stats(struct core *core)
{
    printf("%" PRId64 " total instructions\n", core->total_instructions);
#ifdef DUMP_INSTRUCTION_STATS
#define PRINT_STAT(name) printf("%s %" PRId64 " %.4g%%\n", #name, core->stat ## name, \
		(double) core->stat ## name/ core->total_instructions * 100);

    PRINT_STAT(vector_inst);
    PRINT_STAT(load_inst);
    PRINT_STAT(store_inst);
    PRINT_STAT(branch_inst);
    PRINT_STAT(imm_arith_inst);
    PRINT_STAT(reg_arith_inst);

#undef PRINT_STAT
#endif
}

static void print_thread_registers(const struct thread *thread)
{
    int reg;
    int lane;

    printf("REGISTERS\n");
    for (reg = 0; reg < NUM_REGISTERS - 1; reg++)
    {
        if (reg < 10)
            printf(" "); // Align single digit numbers

        printf("s%d %08x ", reg, thread->scalar_reg[reg]);
        if (reg % 8 == 7)
            printf("\n");
    }

    printf("s31 %08x\n", thread->pc - 4);
    printf("Flags: ");
    if (thread->enable_interrupt)
        printf("I");

    if (thread->enable_mmu)
        printf("M");

    if(thread->enable_supervisor)
        printf("S");

    printf("\n\n");
    for (reg = 0; reg < NUM_REGISTERS; reg++)
    {
        if (reg < 10)
            printf(" "); // Align single digit numbers

        printf("v%d ", reg);
        for (lane = NUM_VECTOR_LANES - 1; lane >= 0; lane--)
            printf("%08x", thread->vector_reg[reg][lane]);

        printf("\n");
    }
}

static uint32_t get_thread_scalar_reg(const struct thread *thread, uint32_t reg)
{
    if (reg == PC_REG)
        return thread->pc;
    else
        return thread->scalar_reg[reg];
}

static void set_scalar_reg(struct thread *thread, uint32_t reg, uint32_t value)
{
    if (thread->core->enable_tracing)
        printf("%08x [th %d] s%d <= %08x\n", thread->pc - 4, thread->id, reg, value);

    if (thread->core->enable_cosim)
        cosim_check_set_scalar_reg(thread->core, thread->pc - 4, reg, value);

    if (reg == PC_REG)
        thread->pc = value;
    else
        thread->scalar_reg[reg] = value;
}

static void set_vector_reg(struct thread *thread, uint32_t reg, uint32_t mask, uint32_t *values)
{
    int lane;

    if (thread->core->enable_tracing)
    {
        printf("%08x [th %d] v%d{%04x} <= ", thread->pc - 4, thread->id, reg,
               mask & 0xffff);
        for (lane = NUM_VECTOR_LANES - 1; lane >= 0; lane--)
            printf("%08x ", values[lane]);

        printf("\n");
    }

    if (thread->core->enable_cosim)
        cosim_check_set_vector_reg(thread->core, thread->pc - 4, reg, mask, values);

    for (lane = 0; lane < NUM_VECTOR_LANES; lane++)
    {
        if (mask & (1 << lane))
            thread->vector_reg[reg][lane] = values[lane];
    }
}

static void invalidate_sync_address(struct core *core, uint32_t address)
{
    uint32_t thread_id;

    for (thread_id = 0; thread_id < core->total_threads; thread_id++)
    {
        if (core->threads[thread_id].last_sync_load_addr == address / CACHE_LINE_LENGTH)
            core->threads[thread_id].last_sync_load_addr = INVALID_ADDR;
    }
}

static void try_to_dispatch_interrupt(struct thread *thread)
{
    if (!thread->enable_interrupt)
        return;

    if ((thread->pending_interrupts & thread->interrupt_mask) != 0)
    {
        // Unlike exceptions, an interrupt saves the PC of the *next* instruction,
        // rather than the current one, but only if a multicycle instruction is
        // not active. Advance the PC here accordingly.
        if (thread->subcycle == 0)
            thread->pc += 4;

        raise_trap(thread, 0, TT_INTERRUPT, false, false);
    }
}

static void raise_trap(struct thread *thread, uint32_t trap_address, enum trap_type type,
                       bool is_store, bool is_data_cache)
{
    if (thread->core->enable_tracing)
    {
        printf("%08x [th %d] trap %d store %d cache %d %08x\n",
               thread->pc - 4, thread->id, type, is_store, is_data_cache,
               trap_address);
    }

    if ((thread->core->stop_on_fault || thread->core->trap_handler_pc == 0)
            && type != TT_TLB_MISS
            && type != TT_INTERRUPT
            && type != TT_SYSCALL)
    {
        printf("Thread %d caught fault %d @%08x\n", thread->id, type, thread->pc - 4);
        print_thread_registers(thread);
        thread->core->crashed = true;
        return;
    }

    // For nested interrupts, push the old saved state into
    // the second save slot.
    thread->saved_trap_state[1] = thread->saved_trap_state[0];

    // Save current trap information
    thread->saved_trap_state[0].trap_cause = type | (is_store ? 0x10ul : 0)
        | (is_data_cache ? 0x20ul : 0);

    // Kludge
    // In most cases, the PC points to the next instruction after the one
    // that is currently executing. The trap PC should point to the one
    // that was trapped on, so we decrement it here. However, a multi-cycle
    // instruction like load_gath resets the PC to the current instruction
    // after it executes. If an interrupt occurs, we need to avoid subtracting
    // four. Other traps types like alignment exceptions or page faults will
    // be raised before the PC is decremented in the scatter/gather routine,
    // so those should still decrement for those trap types.
    if (thread->subcycle != 0 && type == TT_INTERRUPT)
        thread->saved_trap_state[0].pc = thread->pc;
    else
        thread->saved_trap_state[0].pc = thread->pc - 4;

    thread->saved_trap_state[0].enable_interrupt = thread->enable_interrupt;
    thread->saved_trap_state[0].enable_mmu = thread->enable_mmu;
    thread->saved_trap_state[0].enable_supervisor = thread->enable_supervisor;
    thread->saved_trap_state[0].subcycle = thread->subcycle;
    thread->saved_trap_state[0].access_address = trap_address;

    // Update thread state
    thread->enable_interrupt = false;
    if (type == TT_TLB_MISS)
    {
        thread->pc = thread->core->tlb_miss_handler_pc;
        thread->enable_mmu = false;
    }
    else
        thread->pc = thread->core->trap_handler_pc;

    thread->subcycle = 0;
    thread->enable_supervisor = true;
}

// Translate addresses using the translation lookaside buffer. Raise faults
// if necessary.
static bool translate_address(struct thread *thread, uint32_t virtual_address,
                              uint32_t *out_physical_address, bool is_store,
                              bool is_data_access)
{
    int tlb_set;
    int way;
    struct tlb_entry *set_entries;

    if (!thread->enable_mmu)
    {
        if (virtual_address >= thread->core->memory_size && virtual_address < 0xffff0000)
        {
            // This isn't an actual fault supported by the hardware, but a debugging
            // aid only available in the emulator.
            printf("Memory access out of range %08x, pc %08x (MMU not enabled)\n",
                   virtual_address, thread->pc - 4);
            print_thread_registers(thread);
            thread->core->crashed = true;
            return false;
        }

        *out_physical_address = virtual_address;
        return true;
    }

    tlb_set = (virtual_address / PAGE_SIZE) % TLB_SETS;
    set_entries = (is_data_access ? thread->core->dtlb : thread->core->itlb)
                  + tlb_set * TLB_WAYS;
    for (way = 0; way < TLB_WAYS; way++)
    {
        if (set_entries[way].virtual_address == ROUND_TO_PAGE(virtual_address)
                && ((set_entries[way].phys_addr_and_flags & TLB_GLOBAL) != 0
                    || set_entries[way].asid == thread->asid))
        {
            if ((set_entries[way].phys_addr_and_flags & TLB_PRESENT) == 0)
            {
                raise_trap(thread, virtual_address, TT_PAGE_FAULT, is_store,
                           is_data_access);
                return false;
            }

            if ((set_entries[way].phys_addr_and_flags & TLB_SUPERVISOR) != 0
                    && !thread->enable_supervisor)
            {
                raise_trap(thread, virtual_address, TT_SUPERVISOR_ACCESS, is_store,
                           is_data_access);
                return false;
            }

            if ((set_entries[way].phys_addr_and_flags & TLB_EXECUTABLE) == 0
                    && !is_data_access)
            {
                raise_trap(thread, virtual_address, TT_NOT_EXECUTABLE, false, false);
                return false;
            }

            if (is_store && (set_entries[way].phys_addr_and_flags & TLB_WRITE_ENABLE) == 0)
            {
                raise_trap(thread, virtual_address, TT_ILLEGAL_STORE, true,
                           is_data_access);
                return false;
            }

            *out_physical_address = ROUND_TO_PAGE(set_entries[way].phys_addr_and_flags)
                                    | PAGE_OFFSET(virtual_address);

            if (*out_physical_address >= thread->core->memory_size && *out_physical_address < 0xffff0000)
            {
                // This isn't an actual fault supported by the hardware, but a debugging
                // aid only available in the emulator.
                printf("Translated physical address out of range. va %08x pa %08x pc %08x\n",
                       virtual_address, *out_physical_address, thread->pc - 4);
                print_thread_registers(thread);
                thread->core->crashed = true;
                return false;
            }

            return true;
        }
    }

    // No translation found
    raise_trap(thread, virtual_address, TT_TLB_MISS, is_store, is_data_access);
    return false;
}

static uint32_t scalar_arithmetic_op(enum arithmetic_op operation, uint32_t value1, uint32_t value2)
{
    switch (operation)
    {
        case OP_OR:
            return value1 | value2;
        case OP_AND:
            return value1 & value2;
        case OP_XOR:
            return value1 ^ value2;
        case OP_ADD_I:
            return value1 + value2;
        case OP_SUB_I:
            return value1 - value2;
        case OP_MULL_I:
            return value1 * value2;
        case OP_MULH_U:
            return (uint32_t)(((uint64_t)value1 * (uint64_t)value2) >> 32);
        case OP_ASHR:
            return (uint32_t)(((int32_t)value1) >> (value2 & 31));
        case OP_SHR:
            return value1 >> (value2 & 31);
        case OP_SHL:
            return value1 << (value2 & 31);
        case OP_CLZ:
            return value2 == 0 ? 32u : (uint32_t)__builtin_clz(value2);
        case OP_CTZ:
            return value2 == 0 ? 32u : (uint32_t)__builtin_ctz(value2);
        case OP_MOVE:
            return value2;
        case OP_CMPEQ_I:
            return (uint32_t)value1 == value2;
        case OP_CMPNE_I:
            return (uint32_t)value1 != value2;
        case OP_CMPGT_I:
            return (uint32_t)((int32_t)value1 > (int32_t)value2);
        case OP_CMPGE_I:
            return (uint32_t)((int32_t)value1 >= (int32_t)value2);
        case OP_CMPLT_I:
            return (uint32_t)((int32_t)value1 < (int32_t)value2);
        case OP_CMPLE_I:
            return (uint32_t)((int32_t)value1 <= (int32_t)value2);
        case OP_CMPGT_U:
            return (uint32_t)(value1 > value2);
        case OP_CMPGE_U:
            return (uint32_t)(value1 >= value2);
        case OP_CMPLT_U:
            return (uint32_t)(value1 < value2);
        case OP_CMPLE_U:
            return (uint32_t)(value1 <= value2);
        case OP_FTOI:
            return (uint32_t)(int32_t)value_as_float(value2);
        case OP_RECIPROCAL:
        {
            // Reciprocal only has 6 bits of accuracy
            float fresult = 1.0f / value_as_float(value2 & 0xfffe0000);
            uint32_t iresult = value_as_int(fresult);
            if (!isnan(fresult))
                iresult &= 0xfffe0000;	// Truncate, but only if not NaN

            return iresult;
        }

        case OP_SEXT8:
            return (uint32_t)(int32_t)(int8_t)value2;
        case OP_SEXT16:
            return (uint32_t)(int32_t)(int16_t)value2;
        case OP_MULH_I:
            return (uint32_t) (((int64_t)(int32_t)value1 * (int64_t)(int32_t)value2) >> 32);
        case OP_ADD_F:
            return value_as_int(value_as_float(value1) + value_as_float(value2));
        case OP_SUB_F:
            return value_as_int(value_as_float(value1) - value_as_float(value2));
        case OP_MUL_F:
            return value_as_int(value_as_float(value1) * value_as_float(value2));
        case OP_ITOF:
            return value_as_int((float)(int32_t)value2);
        case OP_CMPGT_F:
            return value_as_float(value1) > value_as_float(value2);
        case OP_CMPGE_F:
            return value_as_float(value1) >= value_as_float(value2);
        case OP_CMPLT_F:
            return value_as_float(value1) < value_as_float(value2);
        case OP_CMPLE_F:
            return value_as_float(value1) <= value_as_float(value2);
        case OP_CMPEQ_F:
            return value_as_float(value1) == value_as_float(value2);
        case OP_CMPNE_F:
            return value_as_float(value1) != value_as_float(value2);
        default:
            return 0u;
    }
}

static bool is_compare_op(uint32_t op)
{
    return (op >= OP_CMPEQ_I && op <= OP_CMPLE_U) || (op >= OP_CMPGT_F && op <= OP_CMPNE_F);
}

static struct breakpoint *lookup_breakpoint(struct core *core, uint32_t pc)
{
    struct breakpoint *breakpoint;

    for (breakpoint = core->breakpoints; breakpoint; breakpoint =
                breakpoint->next)
    {
        if (breakpoint->address == pc)
            return breakpoint;
    }

    return NULL;
}

static void execute_register_arith_inst(struct thread *thread, uint32_t instruction)
{
    enum register_arith_format fmt = extract_unsigned_bits(instruction, 26, 3);
    enum arithmetic_op op = extract_unsigned_bits(instruction, 20, 6);
    uint32_t op1reg = extract_unsigned_bits(instruction, 0, 5);
    uint32_t op2reg = extract_unsigned_bits(instruction, 15, 5);
    uint32_t destreg = extract_unsigned_bits(instruction, 5, 5);
    uint32_t maskreg = extract_unsigned_bits(instruction, 10, 5);
    int lane;

    if (op == OP_SYSCALL)
    {
        raise_trap(thread, 0, TT_SYSCALL, false, false);
        return;
    }

    TALLY_INSTRUCTION(reg_arith_inst);
    if (op == OP_GETLANE)
    {
        set_scalar_reg(thread, destreg, thread->vector_reg[op1reg][NUM_VECTOR_LANES - 1
                       - (get_thread_scalar_reg(thread, op2reg) & 0xf)]);
    }
    else if (is_compare_op(op))
    {
        uint32_t result = 0;
        switch (fmt)
        {
            case FMT_RA_SS:
                result = scalar_arithmetic_op(op, get_thread_scalar_reg(thread, op1reg),
                                              get_thread_scalar_reg(thread, op2reg)) ? 0xffff : 0;
                break;

            case FMT_RA_VS:
            case FMT_RA_VS_M:
                TALLY_INSTRUCTION(vector_inst);

                // Vector/Scalar operation
                // Pack compare results in low 16 bits of scalar register
                uint32_t scalar_value = get_thread_scalar_reg(thread, op2reg);
                for (lane = 0; lane < NUM_VECTOR_LANES; lane++)
                {
                    result >>= 1;
                    result |= scalar_arithmetic_op(op, thread->vector_reg[op1reg][lane],
                                                   scalar_value) ? 0x8000 : 0;
                }

                break;

            case FMT_RA_VV:
            case FMT_RA_VV_M:
                TALLY_INSTRUCTION(vector_inst);

                // Vector/Vector operation
                // Pack compare results in low 16 bits of scalar register
                for (lane = 0; lane < NUM_VECTOR_LANES; lane++)
                {
                    result >>= 1;
                    result |= scalar_arithmetic_op(op, thread->vector_reg[op1reg][lane],
                                                   thread->vector_reg[op2reg][lane]) ? 0x8000 : 0;
                }

                break;

            default:
                raise_trap(thread, 0, TT_ILLEGAL_INSTRUCTION, false, false);
                return;
        }

        set_scalar_reg(thread, destreg, result);
    }
    else if (fmt == FMT_RA_SS)
    {
        uint32_t result = scalar_arithmetic_op(op, get_thread_scalar_reg(thread, op1reg),
                                               get_thread_scalar_reg(thread, op2reg));
        set_scalar_reg(thread, destreg, result);
    }
    else
    {
        // Vector arithmetic
        uint32_t result[NUM_VECTOR_LANES];
        uint32_t mask;

        TALLY_INSTRUCTION(vector_inst);
        switch (fmt)
        {
            case FMT_RA_VS_M:
            case FMT_RA_VV_M:
                mask = get_thread_scalar_reg(thread, maskreg);
                break;

            case FMT_RA_VS:
            case FMT_RA_VV:
                mask = 0xffff;
                break;

            default:
                raise_trap(thread, 0, TT_ILLEGAL_INSTRUCTION, false, false);
                return;
        }

        if (op == OP_SHUFFLE)
        {
            const uint32_t *src1 = thread->vector_reg[op1reg];
            const uint32_t *src2 = thread->vector_reg[op2reg];

            for (lane = 0; lane < NUM_VECTOR_LANES; lane++)
                result[lane] = src1[NUM_VECTOR_LANES - 1 - (src2[lane] & 0xf)];
        }
        else if (fmt == FMT_RA_VS || fmt == FMT_RA_VS_M)
        {
            // Vector/Scalar operands
            uint32_t scalar_value = get_thread_scalar_reg(thread, op2reg);
            for (lane = 0; lane < NUM_VECTOR_LANES; lane++)
            {
                result[lane] = scalar_arithmetic_op(op, thread->vector_reg[op1reg][lane],
                                                    scalar_value);
            }
        }
        else
        {
            // Vector/Vector operands
            for (lane = 0; lane < NUM_VECTOR_LANES; lane++)
            {
                result[lane] = scalar_arithmetic_op(op, thread->vector_reg[op1reg][lane],
                                                    thread->vector_reg[op2reg][lane]);
            }
        }

        set_vector_reg(thread, destreg, mask, result);
    }
}

static void execute_immediate_arith_inst(struct thread *thread, uint32_t instruction)
{
    enum immediate_arith_format fmt = extract_unsigned_bits(instruction, 28, 3);
    uint32_t imm_value;
    enum arithmetic_op op = extract_unsigned_bits(instruction, 23, 5);
    uint32_t op1reg = extract_unsigned_bits(instruction, 0, 5);
    uint32_t maskreg = extract_unsigned_bits(instruction, 10, 5);
    uint32_t destreg = extract_unsigned_bits(instruction, 5, 5);
    uint32_t has_mask = fmt == FMT_IMM_VV_M || fmt == FMT_IMM_VS_M;
    int lane;
    uint32_t operand1;

    TALLY_INSTRUCTION(imm_arith_inst);
    if (has_mask)
        imm_value = extract_signed_bits(instruction, 15, 8);
    else
        imm_value = extract_signed_bits(instruction, 10, 13);

    if (op == OP_GETLANE)
    {
        TALLY_INSTRUCTION(vector_inst);
        set_scalar_reg(thread, destreg, thread->vector_reg[op1reg][NUM_VECTOR_LANES - 1 - (imm_value & 0xf)]);
    }
    else if (is_compare_op(op))
    {
        uint32_t result = 0;
        switch (fmt)
        {
            case FMT_IMM_VV:
            case FMT_IMM_VV_M:
                TALLY_INSTRUCTION(vector_inst);

                // Pack compare results into low 16 bits of scalar register
                for (lane = 0; lane < NUM_VECTOR_LANES; lane++)
                {
                    result >>= 1;
                    result |= scalar_arithmetic_op(op, thread->vector_reg[op1reg][lane],
                                                   imm_value) ? 0x8000 : 0;
                }

                break;

            case FMT_IMM_SS:
            case FMT_IMM_VS:
            case FMT_IMM_VS_M:
                result = scalar_arithmetic_op(op, get_thread_scalar_reg(thread, op1reg),
                                              imm_value) ? 0xffff : 0;
                break;

            default:
                raise_trap(thread, 0, TT_ILLEGAL_INSTRUCTION, false, false);
                return;
        }

        set_scalar_reg(thread, destreg, result);
    }
    else if (fmt == FMT_IMM_SS)
    {
        uint32_t result = scalar_arithmetic_op(op, get_thread_scalar_reg(thread, op1reg),
                                               imm_value);
        set_scalar_reg(thread, destreg, result);
    }
    else
    {
        // Vector arithmetic
        uint32_t result[NUM_VECTOR_LANES];
        uint32_t mask;

        TALLY_INSTRUCTION(vector_inst);
        switch (fmt)
        {
            case FMT_IMM_VV_M:
            case FMT_IMM_VS_M:
                mask = get_thread_scalar_reg(thread, maskreg);
                break;

            case FMT_IMM_VV:
            case FMT_IMM_VS:
                mask = 0xffff;
                break;

            default:
                raise_trap(thread, 0, TT_ILLEGAL_INSTRUCTION, false, false);
                return;
        }

        if (fmt == FMT_IMM_VV || fmt == FMT_IMM_VV_M)
        {
            for (lane = 0; lane < NUM_VECTOR_LANES; lane++)
            {
                result[lane] = scalar_arithmetic_op(op, thread->vector_reg[op1reg][lane],
                                                    imm_value);
            }
        }
        else
        {
            operand1 = get_thread_scalar_reg(thread, op1reg);
            for (lane = 0; lane < NUM_VECTOR_LANES; lane++)
                result[lane] = scalar_arithmetic_op(op, operand1, imm_value);
        }

        set_vector_reg(thread, destreg, mask, result);
    }
}

static void execute_scalar_load_store_inst(struct thread *thread, uint32_t instruction)
{
    enum memory_op op = extract_unsigned_bits(instruction, 25, 4);
    uint32_t ptrreg = extract_unsigned_bits(instruction, 0, 5);
    uint32_t offset = extract_signed_bits(instruction, 10, 15);
    uint32_t destsrcreg = extract_unsigned_bits(instruction, 5, 5);
    bool is_load = extract_unsigned_bits(instruction, 29, 1);
    uint32_t virtual_address;
    uint32_t physical_address;
    int is_device_access;
    uint32_t value;
    uint32_t access_size;

    virtual_address = get_thread_scalar_reg(thread, ptrreg) + offset;

    switch (op)
    {
        case MEM_BYTE:
        case MEM_BYTE_SEXT:
            access_size = 1;
            break;

        case MEM_SHORT:
        case MEM_SHORT_EXT:
            access_size = 2;
            break;

        default:
            access_size = 4;
    }

    // Check alignment
    if ((virtual_address % access_size) != 0)
    {
        raise_trap(thread, virtual_address, TT_UNALIGNED_ACCESS, !is_load, true);
        return;
    }

    if (!translate_address(thread, virtual_address, &physical_address, !is_load, true))
        return; // fault raised, bypass other side effects

    is_device_access = (physical_address & 0xffff0000) == 0xffff0000;
    if (is_device_access && op != MEM_LONG)
    {
        // This is not an actual CPU fault, but a debugging aid in the emulator.
        printf("%s Invalid device access %08x, pc %08x\n", is_load ? "Load" : "Store",
               virtual_address, thread->pc - 4);
        print_thread_registers(thread);
        thread->core->crashed = true;
        return;
    }

    if (is_load)
    {
        switch (op)
        {
            case MEM_LONG:
                if (is_device_access)
                    value = read_device_register(physical_address);
                else
                    value = (uint32_t) *UINT32_PTR(thread->core->memory, physical_address);

                break;

            case MEM_BYTE:
                value = (uint32_t) *UINT8_PTR(thread->core->memory, physical_address);
                break;

            case MEM_BYTE_SEXT:
                value = (uint32_t)(int32_t) *INT8_PTR(thread->core->memory, physical_address);
                break;

            case MEM_SHORT:
                value = (uint32_t) *UINT16_PTR(thread->core->memory, physical_address);
                break;

            case MEM_SHORT_EXT:
                value = (uint32_t)(int32_t) *INT16_PTR(thread->core->memory, physical_address);
                break;

            case MEM_SYNC:
                value = *UINT32_PTR(thread->core->memory, physical_address);
                thread->last_sync_load_addr = physical_address / CACHE_LINE_LENGTH;
                break;

            case MEM_CONTROL_REG:
                assert(0);	// Should have been handled in caller
                return;

            default:
                raise_trap(thread, 0, TT_ILLEGAL_INSTRUCTION, false, false);
                return;
        }

        set_scalar_reg(thread, destsrcreg, value);
    }
    else
    {
        // Store
        uint32_t value_to_store = get_thread_scalar_reg(thread, destsrcreg);

        // Some instruction don't update memory, for example: a synchronized store
        // that fails or writes to device memory. This tracks whether they
        // did for the cosimulation code below.
        bool did_write = false;
        switch (op)
        {
            case MEM_BYTE:
            case MEM_BYTE_SEXT:
                *UINT8_PTR(thread->core->memory, physical_address) = (uint8_t) value_to_store;
                did_write = true;
                break;

            case MEM_SHORT:
            case MEM_SHORT_EXT:
                *UINT16_PTR(thread->core->memory, physical_address) = (uint16_t) value_to_store;
                did_write = true;
                break;

            case MEM_LONG:
                if ((physical_address & 0xffff0000) == 0xffff0000)
                {
                    // IO address range
                    if (physical_address == REG_THREAD_RESUME)
                        thread->core->thread_enable_mask |= value_to_store
                                                            & ((1ull << thread->core->total_threads) - 1);
                    else if (physical_address == REG_THREAD_HALT)
                        thread->core->thread_enable_mask &= ~value_to_store;
                    else if (physical_address == REG_TIMER_INT)
                        thread->core->current_timer_count = value_to_store;
                    else
                        write_device_register(physical_address, value_to_store);

                    // Bail to avoid logging and other side effects below.
                    return;
                }

                *UINT32_PTR(thread->core->memory, physical_address) = value_to_store;
                did_write = true;
                break;

            case MEM_SYNC:
                if (physical_address / CACHE_LINE_LENGTH == thread->last_sync_load_addr)
                {
                    // Success

                    // HACK: cosim can only track one side effect per instruction, but sync
                    // store has two: setting the register to indicate success and updating
                    // memory. This only logs the memory transaction. Instead of
                    // calling set_scalar_reg (which would log the register transfer as
                    // a side effect), set the value explicitly here.
                    thread->scalar_reg[destsrcreg] = 1;

                    *UINT32_PTR(thread->core->memory, physical_address) = value_to_store;
                    did_write = true;
                }
                else
                    thread->scalar_reg[destsrcreg] = 0;	// Fail. Set register manually as above.

                break;

            case MEM_CONTROL_REG:
                assert(0);	// Should have been handled in caller
                return;

            default:
                raise_trap(thread, 0, TT_ILLEGAL_INSTRUCTION, false, false);
                return;
        }

        if (did_write)
        {
            invalidate_sync_address(thread->core, physical_address);
            if (thread->core->enable_tracing)
            {
                printf("%08x [th %d] memory store size %d %08x %02x\n", thread->pc - 4,
                       thread->id, access_size, virtual_address, value_to_store);
            }

            if (thread->core->enable_cosim)
            {
                cosim_check_scalar_store(thread->core, thread->pc - 4, virtual_address, access_size,
                                         value_to_store);
            }
        }
    }
}

static void execute_block_load_store_inst(struct thread *thread, uint32_t instruction)
{
    uint32_t op = extract_unsigned_bits(instruction, 25, 4);
    uint32_t ptrreg = extract_unsigned_bits(instruction, 0, 5);
    uint32_t maskreg = extract_unsigned_bits(instruction, 10, 5);
    uint32_t destsrcreg = extract_unsigned_bits(instruction, 5, 5);
    bool is_load = extract_unsigned_bits(instruction, 29, 1);
    uint32_t offset;
    uint32_t lane;
    uint32_t mask;
    uint32_t virtual_address;
    uint32_t physical_address;
    uint32_t *block_ptr;

    TALLY_INSTRUCTION(vector_inst);

    // Compute mask value
    switch (op)
    {
        case MEM_BLOCK_VECTOR:
            mask = 0xffff;
            offset = extract_signed_bits(instruction, 10, 15);
            break;

        case MEM_BLOCK_VECTOR_MASK:
            mask = get_thread_scalar_reg(thread, maskreg);
            offset = extract_signed_bits(instruction, 15, 10);
            break;

        default:
            assert(0);
    }

    virtual_address = get_thread_scalar_reg(thread, ptrreg) + offset;

    // Check alignment
    if ((virtual_address & (NUM_VECTOR_LANES * 4 - 1)) != 0)
    {
        raise_trap(thread, virtual_address, TT_UNALIGNED_ACCESS, !is_load,
                   true);
        return;
    }

    if (!translate_address(thread, virtual_address, &physical_address, !is_load, true))
        return; // fault raised, bypass other side effects

    block_ptr = UINT32_PTR(thread->core->memory, physical_address);
    if (is_load)
    {
        uint32_t load_value[NUM_VECTOR_LANES];
        for (lane = 0; lane < NUM_VECTOR_LANES; lane++)
            load_value[lane] = block_ptr[NUM_VECTOR_LANES - lane - 1];

        set_vector_reg(thread, destsrcreg, mask, load_value);
    }
    else
    {
        uint32_t *store_value = thread->vector_reg[destsrcreg];

        if ((mask & 0xffff) == 0)
            return;	// Hardware ignores block stores with a mask of zero

        if (thread->core->enable_tracing)
        {
            printf("%08x [th %d] write_mem_block %08x\n", thread->pc - 4, thread->id,
                   virtual_address);
        }

        if (thread->core->enable_cosim)
            cosim_check_vector_store(thread->core, thread->pc - 4, virtual_address, mask, store_value);

        for (lane = 0; lane < NUM_VECTOR_LANES; lane++)
        {
            uint32_t reg_index = NUM_VECTOR_LANES - lane - 1;
            if (mask & (1 << reg_index))
                block_ptr[lane] = store_value[reg_index];
        }

        invalidate_sync_address(thread->core, physical_address);
    }
}

static void execute_scatter_gather_inst(struct thread *thread, uint32_t instruction)
{
    uint32_t op = extract_unsigned_bits(instruction, 25, 4);
    uint32_t ptrreg = extract_unsigned_bits(instruction, 0, 5);
    uint32_t maskreg = extract_unsigned_bits(instruction, 10, 5);
    uint32_t destsrcreg = extract_unsigned_bits(instruction, 5, 5);
    bool is_load = extract_unsigned_bits(instruction, 29, 1);
    uint32_t offset;
    uint32_t lane;
    uint32_t mask;
    uint32_t virtual_address;
    uint32_t physical_address;

    TALLY_INSTRUCTION(vector_inst);

    // Compute mask value
    switch (op)
    {
        case MEM_SCGATH:
            mask = 0xffff;
            offset = extract_signed_bits(instruction, 10, 15);
            break;

        case MEM_SCGATH_MASK:
            mask = get_thread_scalar_reg(thread, maskreg);
            offset = extract_signed_bits(instruction, 15, 10);
            break;

        default:
            assert(0);
    }

    lane = NUM_VECTOR_LANES - 1 - thread->subcycle;
    virtual_address = thread->vector_reg[ptrreg][lane] + offset;
    if ((mask & (1 << lane)) && (virtual_address & 3) != 0)
    {
        raise_trap(thread, virtual_address, TT_UNALIGNED_ACCESS, !is_load, true);
        return;
    }

    if (!translate_address(thread, virtual_address, &physical_address, !is_load, true))
        return; // fault raised, bypass other side effects

    if (is_load)
    {
        uint32_t load_value[NUM_VECTOR_LANES];
        memset(load_value, 0, NUM_VECTOR_LANES * sizeof(uint32_t));
        if (mask & (1 << lane))
            load_value[lane] = *UINT32_PTR(thread->core->memory, physical_address);

        set_vector_reg(thread, destsrcreg, mask & (1 << lane), load_value);
    }
    else if (mask & (1 << lane))
    {
        if (thread->core->enable_tracing)
        {
            printf("%08x [th %d] store_scatter (%d) %08x %08x\n", thread->pc - 4,
                   thread->id, thread->subcycle, virtual_address,
                   thread->vector_reg[destsrcreg][lane]);
        }

        *UINT32_PTR(thread->core->memory, physical_address)
            = thread->vector_reg[destsrcreg][lane];
        invalidate_sync_address(thread->core, physical_address);
        if (thread->core->enable_cosim)
        {
            cosim_check_scalar_store(thread->core, thread->pc - 4, virtual_address, 4,
                                     thread->vector_reg[destsrcreg][lane]);
        }
    }

    if (++thread->subcycle == NUM_VECTOR_LANES)
        thread->subcycle = 0; // Finish
    else
        thread->pc -= 4;	// repeat current instruction
}

static void execute_control_register_inst(struct thread *thread, uint32_t instruction)
{
    uint32_t cr_index = extract_unsigned_bits(instruction, 0, 5);
    uint32_t dst_src_reg = extract_unsigned_bits(instruction, 5, 5);
    if (extract_unsigned_bits(instruction, 29, 1))
    {
        // Load
        uint32_t value = 0xffffffff;
        switch (cr_index)
        {
            case CR_THREAD_ID:
                value = thread->id;
                break;

            case CR_TRAP_HANDLER:
                value = thread->core->trap_handler_pc;
                break;

            case CR_TRAP_PC:
                value = thread->saved_trap_state[0].pc;
                break;

            case CR_TRAP_REASON:
                value = thread->saved_trap_state[0].trap_cause;
                break;

            case CR_FLAGS:
                value = (thread->enable_interrupt ? 1 : 0)
                        | (thread->enable_mmu ? 2 : 0)
                        | (thread->enable_supervisor ? 4 : 0);
                break;

            case CR_SAVED_FLAGS:
                value = (thread->saved_trap_state[0].enable_interrupt ? 1 : 0)
                        | (thread->saved_trap_state[0].enable_mmu ? 2 : 0)
                        | (thread->saved_trap_state[0].enable_supervisor ? 4 : 0);
                break;

            case CR_CURRENT_ASID:
                value = thread->asid;
                break;

            case CR_PAGE_DIR:
                value = thread->page_dir;
                break;

            case CR_TRAP_ACCESS_ADDR:
                value = thread->saved_trap_state[0].access_address;
                break;

            case CR_CYCLE_COUNT:
            {
                // Make clock appear to be running at 50Mhz real time, independent
                // of the instruction rate of the emulator.
                struct timeval tv;
                gettimeofday(&tv, NULL);
                value = (uint32_t)(tv.tv_sec * 50000000 + tv.tv_usec * 50)
                        - thread->core->start_cycle_count;
                break;
            }

            case CR_TLB_MISS_HANDLER:
                value = thread->core->tlb_miss_handler_pc;
                break;

            case CR_SCRATCHPAD0:
                value = thread->saved_trap_state[0].scratchpad0;
                break;

            case CR_SCRATCHPAD1:
                value = thread->saved_trap_state[0].scratchpad1;
                break;

            case CR_SUBCYCLE:
                value = thread->saved_trap_state[0].subcycle;
                break;

            case CR_INTERRUPT_PENDING:
                value = thread->pending_interrupts;
                break;
        }

        set_scalar_reg(thread, dst_src_reg, value);
    }
    else
    {
        // Only threads in supervisor mode can write control registers.
        if (!thread->enable_supervisor)
        {
            raise_trap(thread, 0, TT_PRIVILEGED_OP, false, false);
            return;
        }

        // Store
        uint32_t value = get_thread_scalar_reg(thread, dst_src_reg);
        switch (cr_index)
        {
            case CR_TRAP_HANDLER:
                thread->core->trap_handler_pc = value;
                break;

            case CR_TRAP_PC:
                thread->saved_trap_state[0].pc = value;
                break;

            case CR_FLAGS:
                thread->enable_interrupt = (value & 1) != 0;
                thread->enable_mmu = (value & 2) != 0;
                thread->enable_supervisor = (value & 4) != 0;

                // An interrupt may have occurred while interrupts were
                // disabled.
                if (thread->enable_interrupt)
                    try_to_dispatch_interrupt(thread);

                break;

            case CR_SAVED_FLAGS:
                thread->saved_trap_state[0].enable_interrupt = (value & 1) != 0;
                thread->saved_trap_state[0].enable_mmu = (value & 2) != 0;
                thread->saved_trap_state[0].enable_supervisor = (value & 4) != 0;
                break;

            case CR_CURRENT_ASID:
                thread->asid = value;
                break;

            case CR_PAGE_DIR:
                thread->page_dir = value;
                break;

            case CR_TLB_MISS_HANDLER:
                thread->core->tlb_miss_handler_pc = value;
                break;

            case CR_SCRATCHPAD0:
                thread->saved_trap_state[0].scratchpad0 = value;
                break;

            case CR_SCRATCHPAD1:
                thread->saved_trap_state[0].scratchpad1 = value;
                break;

            case CR_SUBCYCLE:
                thread->saved_trap_state[0].subcycle = value;
                break;

            case CR_INTERRUPT_MASK:
                thread->interrupt_mask = value;
                printf("thread %d interrupt mask %08x\n", thread->id, value);
                break;

            case CR_INTERRUPT_ACK:
                thread->pending_interrupts &= ~value;
                break;
        }
    }
}

static void execute_memory_access_inst(struct thread *thread, uint32_t instruction)
{
    uint32_t type = extract_unsigned_bits(instruction, 25, 4);
    if (type != MEM_CONTROL_REG)	// Don't count control register transfers
    {
        if (extract_unsigned_bits(instruction, 29, 1))
            TALLY_INSTRUCTION(load_inst);
        else
            TALLY_INSTRUCTION(store_inst);
    }

    switch (type)
    {
        case MEM_BYTE:
        case MEM_BYTE_SEXT:
        case MEM_SHORT:
        case MEM_SHORT_EXT:
        case MEM_LONG:
        case MEM_SYNC:
            execute_scalar_load_store_inst(thread, instruction);
            break;

        case MEM_CONTROL_REG:
            execute_control_register_inst(thread, instruction);
            break;

        case MEM_BLOCK_VECTOR:
        case MEM_BLOCK_VECTOR_MASK:
            execute_block_load_store_inst(thread, instruction);
            break;

        case MEM_SCGATH:
        case MEM_SCGATH_MASK:
            execute_scatter_gather_inst(thread, instruction);
            break;

        default:
            raise_trap(thread, 0, TT_ILLEGAL_INSTRUCTION, false, false);
    }
}

static void execute_branch_inst(struct thread *thread, uint32_t instruction)
{
    bool branch_taken = false;
    uint32_t src_reg = extract_unsigned_bits(instruction, 0, 5);

    TALLY_INSTRUCTION(branch_inst);
    switch (extract_unsigned_bits(instruction, 25, 3))
    {
        case BRANCH_ALL:
            branch_taken = (get_thread_scalar_reg(thread, src_reg) & 0xffff) == 0xffff;
            break;

        case BRANCH_ZERO:
            branch_taken = get_thread_scalar_reg(thread, src_reg) == 0;
            break;

        case BRANCH_NOT_ZERO:
            branch_taken = get_thread_scalar_reg(thread, src_reg) != 0;
            break;

        case BRANCH_ALWAYS:
            branch_taken = true;
            break;

        case BRANCH_CALL_OFFSET:
            branch_taken = true;
            set_scalar_reg(thread, LINK_REG, thread->pc);
            break;

        case BRANCH_NOT_ALL:
            branch_taken = (get_thread_scalar_reg(thread, src_reg) & 0xffff) != 0xffff;
            break;

        case BRANCH_CALL_REGISTER:
            set_scalar_reg(thread, LINK_REG, thread->pc);
            thread->pc = get_thread_scalar_reg(thread, src_reg);
            return; // Short circuit, since the source register is the dest

        case BRANCH_ERET:
            if (!thread->enable_supervisor)
            {
                raise_trap(thread, 0, TT_PRIVILEGED_OP, false, false);
                return;
            }

            thread->enable_interrupt = thread->saved_trap_state[0].enable_interrupt;
            thread->enable_mmu = thread->saved_trap_state[0].enable_mmu;
            thread->pc = thread->saved_trap_state[0].pc;
            thread->subcycle = thread->saved_trap_state[0].subcycle;
            thread->enable_supervisor = thread->saved_trap_state[0].enable_supervisor;

            // Restore nested interrupt state
            thread->saved_trap_state[0] = thread->saved_trap_state[1];

            // There may be other interrupts pending
            if (thread->enable_interrupt)
                try_to_dispatch_interrupt(thread);

            return; // Short circuit branch side effect below
    }

    if (branch_taken)
        thread->pc += extract_signed_bits(instruction, 5, 20);
}

static void execute_cache_control_inst(struct thread *thread, uint32_t instruction)
{
    uint32_t op = extract_unsigned_bits(instruction, 25, 3);
    uint32_t ptr_reg = extract_unsigned_bits(instruction, 0, 5);
    uint32_t way;
    bool updated_entry;

    switch (op)
    {
        case CC_DINVALIDATE:
            if (!thread->enable_supervisor)
            {
                raise_trap(thread, 0, TT_PRIVILEGED_OP, false, false);
                return;
            }

        // Falls through...

        case CC_DFLUSH:
        {
            // This needs to fault if the TLB entry isn't present. translate_address
            // will do that as a side effect.
            uint32_t offset = extract_signed_bits(instruction, 15, 10);
            uint32_t physical_address;
            translate_address(thread, get_thread_scalar_reg(thread, ptr_reg) + offset,
                              &physical_address, false, true);
            break;
        }

        case CC_DTLB_INSERT:
        case CC_ITLB_INSERT:
        {
            uint32_t virtual_address = ROUND_TO_PAGE(get_thread_scalar_reg(thread, ptr_reg));
            uint32_t phys_addr_reg = extract_unsigned_bits(instruction, 5, 5);
            uint32_t phys_addr_and_flags = get_thread_scalar_reg(thread, phys_addr_reg);
            uint32_t *way_ptr;
            struct tlb_entry *tlb;

            if (!thread->enable_supervisor)
            {
                raise_trap(thread, 0, TT_PRIVILEGED_OP, false, false);
                return;
            }

            if (op == CC_DTLB_INSERT)
            {
                tlb = thread->core->dtlb;
                way_ptr = &thread->core->next_dtlb_way;
            }
            else
            {
                tlb = thread->core->itlb;
                way_ptr = &thread->core->next_itlb_way;
            }

            struct tlb_entry *entry = &tlb[((virtual_address / PAGE_SIZE) % TLB_SETS) * TLB_WAYS];
            updated_entry = false;
            for (way = 0; way < TLB_WAYS; way++)
            {
                if (entry[way].virtual_address == virtual_address
                        && ((entry[way].phys_addr_and_flags & TLB_GLOBAL) != 0
                            || entry[way].asid == thread->asid))
                {
                    // Found existing entry, update it
                    entry[way].phys_addr_and_flags = phys_addr_and_flags;
                    updated_entry = true;
                    break;
                }
            }

            if (!updated_entry)
            {
                // Replace entry with a new one
                entry[*way_ptr].virtual_address = virtual_address;
                entry[*way_ptr].phys_addr_and_flags = phys_addr_and_flags;
                entry[*way_ptr].asid = thread->asid;
            }

            *way_ptr = (*way_ptr + 1) % TLB_WAYS;
            break;
        }

        case CC_INVALIDATE_TLB:
        {
            uint32_t offset = extract_signed_bits(instruction, 15, 10);
            uint32_t virtual_address = ROUND_TO_PAGE(get_thread_scalar_reg(thread, ptr_reg) + offset);
            uint32_t tlb_index = ((virtual_address / PAGE_SIZE) % TLB_SETS) * TLB_WAYS;

            for (way = 0; way < TLB_WAYS; way++)
            {
                if (thread->core->itlb[tlb_index + way].virtual_address == virtual_address)
                    thread->core->itlb[tlb_index + way].virtual_address = INVALID_ADDR;

                if (thread->core->dtlb[tlb_index + way].virtual_address == virtual_address)
                    thread->core->dtlb[tlb_index + way].virtual_address = INVALID_ADDR;
            }

            break;
        }

        case CC_INVALIDATE_TLB_ALL:
        {
            int i;

            for (i = 0; i < TLB_SETS * TLB_WAYS; i++)
            {
                // Set to invalid (unaligned) addresses so these don't match
                thread->core->itlb[i].virtual_address = INVALID_ADDR;
                thread->core->dtlb[i].virtual_address = INVALID_ADDR;
            }

            break;
        }
    }
}

// Returns 0 if this hit a breakpoint and should break out of execution
// loop.
static bool execute_instruction(struct thread *thread)
{
    uint32_t instruction;
    uint32_t physical_pc;
    unsigned int fetch_pc = thread->pc;
    thread->pc += 4;

    // Check PC alignment
    if ((fetch_pc & 3) != 0)
    {
        raise_trap(thread, thread->pc, TT_UNALIGNED_ACCESS, false, false);
        return true;   // XXX if stop on fault was enabled, should return false
    }

    if (!translate_address(thread, fetch_pc, &physical_pc, false, false))
        return true;	// On next execution will start in TLB miss handler

    // XXX if stop on fault was enabled, should return false

    instruction = *UINT32_PTR(thread->core->memory, physical_pc);
    thread->core->total_instructions++;

restart:
    if ((instruction & 0xe0000000) == 0xc0000000)
        execute_register_arith_inst(thread, instruction);
    else if ((instruction & 0x80000000) == 0)
    {
        if (instruction == BREAKPOINT_INST)
        {
            struct breakpoint *breakpoint = lookup_breakpoint(thread->core, thread->pc - 4);
            if (breakpoint == NULL)
            {
                // We use a special instruction to trigger breakpoint lookup
                // as an optimization to avoid doing a lookup on every
                // instruction. In this case, the special instruction was
                // already in the program, so raise a fault.
                raise_trap(thread, 0, TT_ILLEGAL_INSTRUCTION, false, false);
                return true;
            }

            if (breakpoint->restart || thread->core->single_stepping)
            {
                breakpoint->restart = false;
                instruction = breakpoint->original_instruction;
                assert(instruction != BREAKPOINT_INST);
                goto restart;
            }
            else
            {
                // Hit a breakpoint
                breakpoint->restart = true;
                return false;
            }
        }
        else if (instruction != INSTRUCTION_NOP)
        {
            // Don't call this for nop instructions. Although executing
            // the instruction (or s0, s0, s0) has no effect, it would
            // cause a cosimulation mismatch because the verilog model
            // does not generate an event for it.

            execute_immediate_arith_inst(thread, instruction);
        }
    }
    else if ((instruction & 0xc0000000) == 0x80000000)
        execute_memory_access_inst(thread, instruction);
    else if ((instruction & 0xf0000000) == 0xf0000000)
        execute_branch_inst(thread, instruction);
    else if ((instruction & 0xf0000000) == 0xe0000000)
        execute_cache_control_inst(thread, instruction);
    else
        printf("Bad instruction @%08x\n", thread->pc - 4);

    return true;
}

static void timer_tick(struct core *core)
{
    if (core->current_timer_count > 0)
    {
        if (core->current_timer_count-- == 1)
            raise_interrupt(core, INT_TIMER);
    }
}
