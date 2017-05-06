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
#include "processor.h"
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
#define TALLY_INSTRUCTION(type) thread->core->proc->stat ## type++
#else
#define TALLY_INSTRUCTION(type) do { } while (0)
#endif

#define INVALID_ADDR 0xfffffffful


// When a breakpoint is set, this instruction replaces the one at the
// breakpoint address. It is invalid, because it uses a reserved format
// type. The interpreter only performs a breakpoint lookup when it sees
// this instruction as an optimization.
// This is different than the native 'breakpoint' instruction.
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
    uint32_t latched_interrupts;
    bool enable_interrupt;
    bool enable_mmu;
    bool enable_supervisor;
    uint32_t subcycle;
    uint32_t scalar_reg[NUM_REGISTERS];
    uint32_t vector_reg[NUM_REGISTERS][NUM_VECTOR_LANES];

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
    struct processor *proc;
    struct thread *threads;
    uint32_t trap_handler_pc;
    uint32_t tlb_miss_handler_pc;
    uint32_t phys_tlb_update_addr;
    uint32_t is_level_triggered;    // Bitmap
    struct tlb_entry *itlb;
    uint32_t next_itlb_way;
    struct tlb_entry *dtlb;
    uint32_t next_dtlb_way;
};

struct processor
{
    uint32_t total_threads;
    uint32_t thread_enable_mask;
    uint32_t num_cores;
    uint32_t threads_per_core;
    struct core *cores;
    struct breakpoint *breakpoints;
    uint32_t *memory;
    uint32_t memory_size;
    uint32_t interrupt_levels;
    bool crashed;
    bool single_stepping;
    bool stop_on_fault;
    bool enable_tracing;
    bool enable_cosim;
#ifdef DUMP_INSTRUCTION_STATS
    int64_t stat_vector_inst;
    int64_t stat_load_inst;
    int64_t stat_store_inst;
    int64_t stat_branch_inst;
    int64_t stat_imm_arith_inst;
    int64_t stat_reg_arith_inst;
#endif
    uint32_t current_timer_count;
    int64_t total_instructions;
    uint32_t start_cycle_count;
};

struct breakpoint
{
    struct breakpoint *next;
    uint32_t address;
    uint32_t original_instruction;
    bool restart;
};

static inline const struct thread *get_const_thread(const struct processor *proc, uint32_t thread_id);
static inline struct thread *get_thread(struct processor *proc, uint32_t thread_id);
static void print_thread_registers(const struct thread*);
static void set_scalar_reg(struct thread*, uint32_t reg, uint32_t value);
static void set_vector_reg(struct thread*, uint32_t reg, uint32_t mask,
                           uint32_t *values);
static void invalidate_sync_address(struct core*, uint32_t address);
static void try_to_dispatch_interrupt(struct thread*);
static uint32_t get_pending_interrupts(struct thread*);
static const char *get_trap_name(enum trap_type);
static void raise_trap(struct thread*, uint32_t address, enum trap_type type, bool is_store,
                       bool is_data_cache);
static bool translate_address(struct thread*, uint32_t virtual_address, uint32_t
                              *physical_address, bool is_store, bool is_data_cache);
static uint32_t scalar_arithmetic_op(enum arithmetic_op, uint32_t value1, uint32_t value2);
static bool is_compare_op(uint32_t op);
static struct breakpoint *lookup_breakpoint(struct processor*, uint32_t pc);
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
static void timer_tick(struct processor *proc);

struct processor *init_processor(uint32_t memory_size, uint32_t num_cores,
                                 uint32_t threads_per_core, bool randomize_memory,
                                 const char *shared_memory_file)
{
    uint32_t address;
    uint32_t thread_id;
    uint32_t core_id;
    struct processor *proc;
    struct core *core;
    int i;
    struct timeval tv;
    int shared_memory_fd;

    // Limited by enable mask
    assert(num_cores * threads_per_core <= 32);

    proc = (struct processor*) calloc(sizeof(struct processor), 1);
    proc->memory_size = memory_size;
    if (shared_memory_file != NULL)
    {
        shared_memory_fd = open(shared_memory_file, O_CREAT | O_RDWR, 666);
        if (shared_memory_fd < 0)
        {
            perror("init_processor: Error opening shared memory file");
            free(proc);
            return NULL;
        }

        if (ftruncate(shared_memory_fd, memory_size) < 0)
        {
            perror("init_processor: couldn't resize shared memory file");
            free(proc);
            return NULL;
        }

        proc->memory = mmap(NULL, memory_size, PROT_READ | PROT_WRITE, MAP_SHARED
                            | MAP_FILE, shared_memory_fd, 0);
        if (proc->memory == NULL)
        {
            perror("init_processor: mmap failed");
            free(proc);
            return NULL;
        }
    }
    else
    {
        proc->memory = (uint32_t*) malloc(memory_size);
        if (proc->memory == NULL)
        {
            perror("init_processor: malloc failed");
            free(proc);
            return NULL;
        }

        if (randomize_memory)
        {
            srand((unsigned int) time(NULL));
            for (address = 0; address < memory_size / 4; address++)
                proc->memory[address] = (uint32_t) rand();
        }
        else
            memset(proc->memory, 0, proc->memory_size);
    }

    proc->cores = (struct core*) calloc(sizeof(struct core), num_cores);
    for (core_id = 0; core_id < num_cores; core_id++)
    {
        core = &proc->cores[core_id];
        core->proc = proc;
        core->itlb = (struct tlb_entry*) malloc(sizeof(struct tlb_entry) * TLB_SETS * TLB_WAYS);
        core->dtlb = (struct tlb_entry*) malloc(sizeof(struct tlb_entry) * TLB_SETS * TLB_WAYS);
        for (i = 0; i < TLB_SETS * TLB_WAYS; i++)
        {
            // Set to invalid (unaligned) addresses so these don't match
            core->itlb[i].virtual_address = INVALID_ADDR;
            core->dtlb[i].virtual_address = INVALID_ADDR;
        }

        core->threads = (struct thread*) calloc(sizeof(struct thread), threads_per_core);
        for (thread_id = 0; thread_id < threads_per_core; thread_id++)
        {
            core->threads[thread_id].core = core;
            core->threads[thread_id].id = core_id * threads_per_core + thread_id;
            core->threads[thread_id].last_sync_load_addr = INVALID_ADDR;
            core->threads[thread_id].enable_supervisor = true;
            core->threads[thread_id].saved_trap_state[0].enable_supervisor = true;
        }

        core->trap_handler_pc = 0;
    }

    proc->total_threads = threads_per_core * num_cores;
    proc->threads_per_core = threads_per_core;
    proc->num_cores = num_cores;
    proc->crashed = false;
    proc->thread_enable_mask = 1;
    proc->enable_tracing = false;
    gettimeofday(&tv, NULL);
    proc->start_cycle_count = (uint32_t)(tv.tv_sec * 50000000 + tv.tv_usec * 50);

    return proc;
}

void enable_tracing(struct processor *proc)
{
    proc->enable_tracing = true;
}

int load_hex_file(struct processor *proc, const char *filename)
{
    FILE *file;
    char line[16];
    uint32_t *memptr = proc->memory;

    file = fopen(filename, "r");
    if (file == NULL)
    {
        perror("load_hex_file: error opening hex file");
        return -1;
    }

    while (fgets(line, sizeof(line), file))
    {
        *memptr++ = endian_swap32((uint32_t) strtoul(line, NULL, 16));
        if ((uint32_t)((memptr - proc->memory) * 4) >= proc->memory_size)
        {
            fclose(file);
            fprintf(stderr, "load_hex_file: hex file too big to fit in memory\n");
            return -1;
        }
    }

    fclose(file);

    return 0;
}

void write_memory_to_file(const struct processor *proc, const char *filename,
                          uint32_t base_address, uint32_t length)
{
    FILE *file;

    file = fopen(filename, "wb+");
    if (file == NULL)
    {
        perror("write_memory_to_file: Error opening output file");
        return;
    }

    if (fwrite((int8_t*) proc->memory + base_address, MIN(proc->memory_size, length), 1, file) <= 0)
    {
        fclose(file);
        perror("write_memory_to_file: fwrite failed");
        return;
    }

    fclose(file);
}

const void *get_memory_region_ptr(const struct processor *proc, uint32_t address, uint32_t length)
{
    assert(length < proc->memory_size);

    // Prevent overrun for bad address
    if (address > proc->memory_size || address + length > proc->memory_size)
        return proc->memory;

    return ((const uint8_t*) proc->memory) + address;
}

void print_registers(const struct processor *proc, uint32_t thread_id)
{
    print_thread_registers(get_const_thread(proc, thread_id));
}

void enable_cosimulation(struct processor *proc)
{
    proc->enable_cosim = true;
}

void raise_interrupt(struct processor *proc, uint32_t int_bitmap)
{
    uint32_t thread_id;
    uint32_t core_id;
    struct core *core;
    struct thread *thread;

    proc->interrupt_levels |= int_bitmap;
    for (core_id = 0; core_id < proc->num_cores; core_id++)
    {
        core = &proc->cores[core_id];
        for (thread_id = 0; thread_id < proc->threads_per_core; thread_id++)
        {
            thread = &core->threads[thread_id];
            thread->latched_interrupts |= int_bitmap;
            try_to_dispatch_interrupt(thread);
        }
    }
}

void clear_interrupt(struct processor *proc, uint32_t int_bitmap)
{
    proc->interrupt_levels &= ~int_bitmap;
}

// Called when the verilog model in cosimulation indicates an interrupt.
void cosim_interrupt(struct processor *proc, uint32_t thread_id, uint32_t pc)
{
    struct thread *thread = get_thread(proc, thread_id);

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
    thread->latched_interrupts |= INT_COSIM;
    try_to_dispatch_interrupt(thread);
}

uint32_t get_total_threads(const struct processor *proc)
{
    return proc->total_threads;
}

bool is_proc_halted(const struct processor *proc)
{
    return proc->thread_enable_mask == 0 || proc->crashed;
}

bool is_stopped_on_fault(const struct processor *proc)
{
    return proc->crashed;
}

bool execute_instructions(struct processor *proc, uint32_t thread_id,
                          uint64_t total_instructions)
{
    uint64_t instruction_count;
    uint32_t local_thread_idx;
    uint32_t core_id;
    struct core *core;

    proc->single_stepping = false;
    for (instruction_count = 0; instruction_count < total_instructions; instruction_count++)
    {
        if (proc->thread_enable_mask == 0)
        {
            printf("thread enable mask is now zero\n");
            return false;
        }

        if (proc->crashed)
            return false;

        if (thread_id == ALL_THREADS)
        {
            // Cycle through threads round-robin
            for (core_id = 0; core_id < proc->num_cores; core_id++)
            {
                core = &proc->cores[core_id];
                for (local_thread_idx = 0; local_thread_idx < proc->threads_per_core;
                        local_thread_idx++)
                {
                    if (proc->thread_enable_mask & (1 << local_thread_idx))
                    {
                        if (!execute_instruction(&core->threads[local_thread_idx]))
                            return false;  // Hit breakpoint
                    }
                }
            }
        }
        else
        {
            if (!execute_instruction(get_thread(proc, thread_id)))
                return false;  // Hit breakpoint
        }

        timer_tick(proc);
    }

    return true;
}

uint32_t dbg_get_pc(struct processor *proc, uint32_t thread_id)
{
    return get_thread(proc, thread_id)->pc;
}

void dbg_single_step(struct processor *proc, uint32_t thread_id)
{
    proc->single_stepping = true;
    execute_instruction(get_thread(proc, thread_id));
    timer_tick(proc);
}

uint32_t dbg_get_scalar_reg(const struct processor *proc, uint32_t thread_id,
                            uint32_t reg_id)
{
    return get_const_thread(proc, thread_id)->scalar_reg[reg_id];
}

void dbg_set_scalar_reg(struct processor *proc, uint32_t thread_id,
                        uint32_t reg_id, uint32_t value)
{
    set_scalar_reg(get_thread(proc, thread_id), reg_id, value);
}

void dbg_get_vector_reg(const struct processor *proc, uint32_t thread_id,
                        uint32_t reg_id, uint32_t *values)
{
    memcpy(values, get_const_thread(proc, thread_id)->vector_reg[reg_id],
           NUM_VECTOR_LANES * sizeof(int));
}

void dbg_set_vector_reg(struct processor *proc, uint32_t thread_id,
                        uint32_t reg_id, uint32_t *values)
{
    memcpy(get_thread(proc, thread_id)->vector_reg[reg_id], values,
           NUM_VECTOR_LANES * sizeof(int));
}

// XXX This does not perform address translation.
// We can't handle TLB misses properly when the fault is caued by debugger.
// Should either do a best effort, returning nothing if the TLB entry is missing,
// or return an error if memory translation is enabled.
uint32_t dbg_read_memory_byte(const struct processor *proc, uint32_t address)
{
    if (address >= proc->memory_size)
        return 0xff;

    return ((uint8_t*)proc->memory)[address];
}

void dbg_write_memory_byte(const struct processor *proc, uint32_t address, uint8_t byte)
{
    if (address < proc->memory_size)
        ((uint8_t*)proc->memory)[address] = byte;
}

int dbg_set_breakpoint(struct processor *proc, uint32_t pc)
{
    struct breakpoint *breakpoint = lookup_breakpoint(proc, pc);
    if (breakpoint != NULL)
    {
        printf("already has a breakpoint at address %x\n", pc);
        return -1;
    }

    if (pc >= proc->memory_size || (pc & 3) != 0)
    {
        printf("invalid breakpoint address %x\n", pc);
        return -1;
    }

    breakpoint = (struct breakpoint*) calloc(sizeof(struct breakpoint), 1);
    breakpoint->next = proc->breakpoints;
    proc->breakpoints = breakpoint;
    breakpoint->address = pc;
    breakpoint->original_instruction = proc->memory[pc / 4];
    if (breakpoint->original_instruction == BREAKPOINT_INST)
        breakpoint->original_instruction = INSTRUCTION_NOP;	// Avoid infinite loop

    proc->memory[pc / 4] = BREAKPOINT_INST;
    return 0;
}

int dbg_clear_breakpoint(struct processor *proc, uint32_t pc)
{
    struct breakpoint **link;
    struct breakpoint *breakpoint;

    for (link = &proc->breakpoints; *link; link = &(*link)->next)
    {
        breakpoint = *link;
        if (breakpoint->address == pc)
        {
            proc->memory[pc / 4] = breakpoint->original_instruction;
            *link = breakpoint->next;
            free(breakpoint);
            return 0;
        }
    }

    return -1; // Not found
}

void dbg_set_stop_on_fault(struct processor *proc, bool stop_on_fault)
{
    proc->stop_on_fault = stop_on_fault;
}

void dump_instruction_stats(struct processor *proc)
{
    printf("%" PRId64 " total instructions\n", proc->total_instructions);
#ifdef DUMP_INSTRUCTION_STATS
#define PRINT_STAT(name) printf("%s %" PRId64 " %.4g%%\n", #name, proc->stat ## name, \
		(double) proc->stat ## name / proc->total_instructions * 100);

    PRINT_STAT(vector_inst);
    PRINT_STAT(load_inst);
    PRINT_STAT(store_inst);
    PRINT_STAT(branch_inst);
    PRINT_STAT(imm_arith_inst);
    PRINT_STAT(reg_arith_inst);

#undef PRINT_STAT
#endif
}

static inline const struct thread *get_const_thread(const struct processor
        *proc, uint32_t thread_id)
{
    return &proc->cores[thread_id / proc->threads_per_core].threads[
               thread_id % proc->threads_per_core];
}

static inline struct thread *get_thread(struct processor *proc, uint32_t thread_id)
{
    return &proc->cores[thread_id / proc->threads_per_core].threads[
               thread_id % proc->threads_per_core];
}

static void print_thread_registers(const struct thread *thread)
{
    int reg;
    int lane;

    printf("REGISTERS\n");
    for (reg = 0; reg < NUM_REGISTERS; reg++)
    {
        if (reg < 10)
            printf(" "); // Align single digit numbers

        printf("s%d %08x ", reg, thread->scalar_reg[reg]);
        if (reg % 8 == 7)
            printf("\n");
    }

    printf("pc %08x ", thread->pc - 4);
    printf("flags: ");
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
        for (lane = 0; lane < NUM_VECTOR_LANES; lane++)
            printf("%08x", thread->vector_reg[reg][lane]);

        printf("\n");
    }
}

static void set_scalar_reg(struct thread *thread, uint32_t reg, uint32_t value)
{
    if (thread->core->proc->enable_tracing)
        printf("%08x [th %u] s%d <= %08x\n", thread->pc - 4, thread->id, reg, value);

    if (thread->core->proc->enable_cosim)
    {
        cosim_check_set_scalar_reg(thread->core->proc, thread->pc - 4,
                                   reg, value);
    }

    thread->scalar_reg[reg] = value;
}

static void set_vector_reg(struct thread *thread, uint32_t reg, uint32_t mask,
                           uint32_t *values)
{
    int lane;

    if (thread->core->proc->enable_tracing)
    {
        printf("%08x [th %u] v%d{%04x} <= ", thread->pc - 4, thread->id, reg,
               mask & 0xffff);
        for (lane = 0; lane < NUM_VECTOR_LANES; lane++)
            printf("%08x ", values[lane]);

        printf("\n");
    }

    if (thread->core->proc->enable_cosim)
        cosim_check_set_vector_reg(thread->core->proc, thread->pc - 4, reg, mask, values);

    for (lane = 0; lane < NUM_VECTOR_LANES; lane++)
    {
        if (mask & (1 << lane))
            thread->vector_reg[reg][lane] = values[lane];
    }
}

static void invalidate_sync_address(struct core *core, uint32_t address)
{
    uint32_t thread_id;

    for (thread_id = 0; thread_id < core->proc->total_threads; thread_id++)
    {
        if (core->threads[thread_id].last_sync_load_addr == address / CACHE_LINE_LENGTH)
            core->threads[thread_id].last_sync_load_addr = INVALID_ADDR;
    }
}

static void try_to_dispatch_interrupt(struct thread *thread)
{
    uint32_t pending = get_pending_interrupts(thread);
    if (!thread->enable_interrupt)
        return;

    if ((pending & thread->interrupt_mask) != 0)
    {
        // Unlike exceptions, an interrupt saves the PC of the *next* instruction,
        // rather than the current one, but only if a multicycle instruction is
        // not active. Advance the PC here accordingly.
        if (thread->subcycle == 0)
            thread->pc += 4;

        raise_trap(thread, 0, TT_INTERRUPT, false, false);
    }
}

static uint32_t get_pending_interrupts(struct thread *thread)
{
    return (thread->core->is_level_triggered & thread->core->proc->interrupt_levels)
           | (~thread->core->is_level_triggered & thread->latched_interrupts);
}

static const char *get_trap_name(enum trap_type type)
{
#define TRAP_ENTRY(x)  case TT_ ## x: return #x;
    switch (type)
    {
        TRAP_ENTRY(RESET)
        TRAP_ENTRY(ILLEGAL_INSTRUCTION)
        TRAP_ENTRY(PRIVILEGED_OP)
        TRAP_ENTRY(INTERRUPT)
        TRAP_ENTRY(SYSCALL)
        TRAP_ENTRY(UNALIGNED_ACCESS)
        TRAP_ENTRY(PAGE_FAULT)
        TRAP_ENTRY(TLB_MISS)
        TRAP_ENTRY(ILLEGAL_STORE)
        TRAP_ENTRY(SUPERVISOR_ACCESS)
        TRAP_ENTRY(NOT_EXECUTABLE)
        TRAP_ENTRY(BREAKPOINT)
        default:
            return "???";
    }
#undef TRAP_ENTRY
}

static void raise_trap(struct thread *thread, uint32_t trap_address, enum trap_type type,
                       bool is_store, bool is_data_cache)
{
    if (thread->core->proc->enable_tracing)
    {
        printf("%08x [th %u] trap %d store %d cache %d %08x\n",
               thread->pc - 4, thread->id, type, is_store, is_data_cache,
               trap_address);
    }

    if ((thread->core->proc->stop_on_fault || thread->core->trap_handler_pc == 0)
            && type != TT_TLB_MISS
            && type != TT_INTERRUPT
            && type != TT_SYSCALL)
    {
        thread->pc -= 4;    // reset PC to faulting instruction
        printf("Thread %u caught fault %s @%08x\n", thread->id,
            get_trap_name(type), thread->pc);
        print_thread_registers(thread);
        thread->core->proc->crashed = true;
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

// Translate addresses using the translation lookaside buffer. Returns true
// if there was a valid translation, false otherwise (in the latter case, it
// will also raise a trap or print an error as a side effect).
static bool translate_address(struct thread *thread, uint32_t virtual_address,
                              uint32_t *out_physical_address, bool is_store,
                              bool is_data_access)
{
    int tlb_set;
    int way;
    struct tlb_entry *set_entries;

    if (!thread->enable_mmu)
    {
        if (virtual_address >= thread->core->proc->memory_size && virtual_address < 0xffff0000)
        {
            // This isn't an actual fault supported by the hardware, but a debugging
            // aid only available in the emulator.
            printf("Memory access out of range %08x, pc %08x (MMU not enabled)\n",
                   virtual_address, thread->pc - 4);
            print_thread_registers(thread);
            thread->core->proc->crashed = true;
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

            if (*out_physical_address >= thread->core->proc->memory_size && *out_physical_address < 0xffff0000)
            {
                // This isn't an actual fault supported by the hardware, but a debugging
                // aid only available in the emulator.
                printf("Translated physical address out of range. va %08x pa %08x pc %08x\n",
                       virtual_address, *out_physical_address, thread->pc - 4);
                print_thread_registers(thread);
                thread->core->proc->crashed = true;
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

static struct breakpoint *lookup_breakpoint(struct processor *proc, uint32_t pc)
{
    struct breakpoint *breakpoint;

    for (breakpoint = proc->breakpoints; breakpoint; breakpoint =
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

    if (op == OP_BREAKPOINT)
    {
        raise_trap(thread, 0, TT_BREAKPOINT, false, false);
        return;
    }


    TALLY_INSTRUCTION(reg_arith_inst);
    if (op == OP_GETLANE)
    {
        set_scalar_reg(thread, destreg, thread->vector_reg[op1reg]
                       [thread->scalar_reg[op2reg] & 0xf]);
    }
    else if (is_compare_op(op))
    {
        uint32_t result = 0;
        switch (fmt)
        {
            case FMT_RA_SS:
                result = scalar_arithmetic_op(op, thread->scalar_reg[op1reg],
                                              thread->scalar_reg[op2reg]) ? 0xffff : 0;
                break;

            case FMT_RA_VS:
            case FMT_RA_VS_M:
                TALLY_INSTRUCTION(vector_inst);

                // Vector/Scalar operation
                // Pack compare results in low 16 bits of scalar register
                uint32_t scalar_value = thread->scalar_reg[op2reg];
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
        uint32_t result = scalar_arithmetic_op(op, thread->scalar_reg[op1reg],
                                               thread->scalar_reg[op2reg]);
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
                mask = thread->scalar_reg[maskreg];
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
                result[lane] = src1[src2[lane] & 0xf];
        }
        else if (fmt == FMT_RA_VS || fmt == FMT_RA_VS_M)
        {
            // Vector/Scalar operands
            uint32_t scalar_value = thread->scalar_reg[op2reg];
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
    enum immediate_arith_format fmt = extract_unsigned_bits(instruction, 29, 2);
    uint32_t imm_value;
    enum arithmetic_op op = extract_unsigned_bits(instruction, 24, 5);
    uint32_t op1reg = extract_unsigned_bits(instruction, 0, 5);
    uint32_t maskreg = extract_unsigned_bits(instruction, 10, 5);
    uint32_t destreg = extract_unsigned_bits(instruction, 5, 5);
    int lane;

    TALLY_INSTRUCTION(imm_arith_inst);
    switch (fmt) {
        case FMT_IMM_VM:
            imm_value = extract_signed_bits(instruction, 15, 9);
            break;

        case FMT_IMM_MOVEHI:
            imm_value = (extract_unsigned_bits(instruction, 10, 14) << 18)
                | (extract_unsigned_bits(instruction, 0, 5) << 13);
            break;

        default:
            imm_value = extract_signed_bits(instruction, 10, 14);
            break;
    }

    if (op == OP_GETLANE)
    {
        TALLY_INSTRUCTION(vector_inst);
        set_scalar_reg(thread, destreg, thread->vector_reg[op1reg][imm_value & 0xf]);
    }
    else if (is_compare_op(op))
    {
        uint32_t result = 0;
        switch (fmt)
        {
            case FMT_IMM_V:
            case FMT_IMM_VM:
                TALLY_INSTRUCTION(vector_inst);

                // Pack compare results into low 16 bits of scalar register
                for (lane = 0; lane < NUM_VECTOR_LANES; lane++)
                {
                    result >>= 1;
                    result |= scalar_arithmetic_op(op, thread->vector_reg[op1reg][lane],
                                                   imm_value) ? 0x8000 : 0;
                }

                break;

            case FMT_IMM_S:
                result = scalar_arithmetic_op(op, thread->scalar_reg[op1reg],
                                              imm_value) ? 0xffff : 0;
                break;

            default:
                raise_trap(thread, 0, TT_ILLEGAL_INSTRUCTION, false, false);
                return;
        }

        set_scalar_reg(thread, destreg, result);
    }
    else if (fmt == FMT_IMM_S || fmt == FMT_IMM_MOVEHI)
    {
        uint32_t result = scalar_arithmetic_op(op, thread->scalar_reg[op1reg],
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
            case FMT_IMM_VM:
                mask = thread->scalar_reg[maskreg];
                break;

            case FMT_IMM_V:
                mask = 0xffff;
                break;

            default:
                raise_trap(thread, 0, TT_ILLEGAL_INSTRUCTION, false, false);
                return;
        }

        for (lane = 0; lane < NUM_VECTOR_LANES; lane++)
        {
            result[lane] = scalar_arithmetic_op(op, thread->vector_reg[op1reg][lane],
                                                imm_value);
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

    virtual_address = thread->scalar_reg[ptrreg] + offset;

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
        thread->core->proc->crashed = true;
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
                    value = (uint32_t) *UINT32_PTR(thread->core->proc->memory, physical_address);

                break;

            case MEM_BYTE:
                value = (uint32_t) *UINT8_PTR(thread->core->proc->memory, physical_address);
                break;

            case MEM_BYTE_SEXT:
                value = (uint32_t)(int32_t) *INT8_PTR(thread->core->proc->memory, physical_address);
                break;

            case MEM_SHORT:
                value = (uint32_t) *UINT16_PTR(thread->core->proc->memory, physical_address);
                break;

            case MEM_SHORT_EXT:
                value = (uint32_t)(int32_t) *INT16_PTR(thread->core->proc->memory, physical_address);
                break;

            case MEM_SYNC:
                value = *UINT32_PTR(thread->core->proc->memory, physical_address);
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
        uint32_t value_to_store = thread->scalar_reg[destsrcreg];

        // Some instruction don't update memory, for example: a synchronized store
        // that fails or writes to device memory. This tracks whether they
        // did for the cosimulation code below.
        bool did_write = false;
        switch (op)
        {
            case MEM_BYTE:
            case MEM_BYTE_SEXT:
                *UINT8_PTR(thread->core->proc->memory, physical_address) = (uint8_t) value_to_store;
                did_write = true;
                break;

            case MEM_SHORT:
            case MEM_SHORT_EXT:
                *UINT16_PTR(thread->core->proc->memory, physical_address) = (uint16_t) value_to_store;
                did_write = true;
                break;

            case MEM_LONG:
                if ((physical_address & 0xffff0000) == 0xffff0000)
                {
                    // IO address range
                    if (physical_address == REG_THREAD_RESUME)
                        thread->core->proc->thread_enable_mask |= value_to_store
                                & ((1ull << thread->core->proc->total_threads) - 1);
                    else if (physical_address == REG_THREAD_HALT)
                        thread->core->proc->thread_enable_mask &= ~value_to_store;
                    else if (physical_address == REG_TIMER_INT)
                        thread->core->proc->current_timer_count = value_to_store;
                    else
                        write_device_register(physical_address, value_to_store);

                    // Bail to avoid logging and other side effects below.
                    return;
                }

                *UINT32_PTR(thread->core->proc->memory, physical_address) = value_to_store;
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

                    *UINT32_PTR(thread->core->proc->memory, physical_address) = value_to_store;
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
            if (thread->core->proc->enable_tracing)
            {
                printf("%08x [th %u] memory store size %d %08x %02x\n", thread->pc - 4,
                       thread->id, access_size, virtual_address, value_to_store);
            }

            if (thread->core->proc->enable_cosim)
            {
                cosim_check_scalar_store(thread->core->proc, thread->pc - 4, virtual_address, access_size,
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
            mask = thread->scalar_reg[maskreg];
            offset = extract_signed_bits(instruction, 15, 10);
            break;

        default:
            assert(0);
    }

    virtual_address = thread->scalar_reg[ptrreg] + offset;

    // Check alignment
    if ((virtual_address & (NUM_VECTOR_LANES * 4 - 1)) != 0)
    {
        raise_trap(thread, virtual_address, TT_UNALIGNED_ACCESS, !is_load,
                   true);
        return;
    }

    if (!translate_address(thread, virtual_address, &physical_address, !is_load, true))
        return; // fault raised, bypass other side effects

    block_ptr = UINT32_PTR(thread->core->proc->memory, physical_address);
    if (is_load)
    {
        uint32_t load_value[NUM_VECTOR_LANES];
        for (lane = 0; lane < NUM_VECTOR_LANES; lane++)
            load_value[lane] = block_ptr[lane];

        set_vector_reg(thread, destsrcreg, mask, load_value);
    }
    else
    {
        uint32_t *store_value = thread->vector_reg[destsrcreg];

        if ((mask & 0xffff) == 0)
            return;	// Hardware ignores block stores with a mask of zero

        if (thread->core->proc->enable_tracing)
        {
            printf("%08x [th %u] write_mem_block %08x\n", thread->pc - 4, thread->id,
                   virtual_address);
        }

        if (thread->core->proc->enable_cosim)
            cosim_check_vector_store(thread->core->proc, thread->pc - 4, virtual_address, mask, store_value);

        for (lane = 0; lane < NUM_VECTOR_LANES; lane++)
        {
            if (mask & (1 << lane))
                block_ptr[lane] = store_value[lane];
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
            mask = thread->scalar_reg[maskreg];
            offset = extract_signed_bits(instruction, 15, 10);
            break;

        default:
            assert(0);
    }

    lane = thread->subcycle;
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
            load_value[lane] = *UINT32_PTR(thread->core->proc->memory, physical_address);

        set_vector_reg(thread, destsrcreg, mask & (1 << lane), load_value);
    }
    else if (mask & (1 << lane))
    {
        if (thread->core->proc->enable_tracing)
        {
            printf("%08x [th %u] store_scatter (%u) %08x %08x\n", thread->pc - 4,
                   thread->id, thread->subcycle, virtual_address,
                   thread->vector_reg[destsrcreg][lane]);
        }

        *UINT32_PTR(thread->core->proc->memory, physical_address)
            = thread->vector_reg[destsrcreg][lane];
        invalidate_sync_address(thread->core, physical_address);
        if (thread->core->proc->enable_cosim)
        {
            cosim_check_scalar_store(thread->core->proc, thread->pc - 4, virtual_address, 4,
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

    // Only threads in supervisor mode can access control registers.
    if (!thread->enable_supervisor)
    {
        raise_trap(thread, 0, TT_PRIVILEGED_OP, false, false);
        return;
    }

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
                        - thread->core->proc->start_cycle_count;
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
                value = get_pending_interrupts(thread);
                break;
        }

        set_scalar_reg(thread, dst_src_reg, value);
    }
    else
    {
        // Store
        uint32_t value = thread->scalar_reg[dst_src_reg];
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
                break;

            case CR_INTERRUPT_ACK:
                thread->latched_interrupts &= ~value;
                break;

            case CR_INTERRUPT_TRIGGER:
                thread->core->is_level_triggered = value;
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
    uint32_t src_reg = extract_unsigned_bits(instruction, 0, 5);

    // Subtract 4 because PC was already incremented after fetching instruction
    uint32_t offset20 = extract_signed_bits(instruction, 5, 20) * 4 - 4;
    uint32_t offset25 = extract_signed_bits(instruction, 0, 25) * 4 - 4;

    TALLY_INSTRUCTION(branch_inst);
    switch (extract_unsigned_bits(instruction, 25, 3))
    {
        case BRANCH_REGISTER:
            thread->pc = thread->scalar_reg[src_reg];
            break;

        case BRANCH_ZERO:
            if (thread->scalar_reg[src_reg] == 0)
                thread->pc += offset20;

            break;

        case BRANCH_NOT_ZERO:
            if (thread->scalar_reg[src_reg] != 0)
                thread->pc += offset20;

            break;

        case BRANCH_ALWAYS:
            thread->pc += offset25;
            break;

        case BRANCH_CALL_OFFSET:
            set_scalar_reg(thread, LINK_REG, thread->pc);
            thread->pc += offset25;
            break;

        case BRANCH_CALL_REGISTER:
            set_scalar_reg(thread, LINK_REG, thread->pc);
            thread->pc = thread->scalar_reg[src_reg];
            break;

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

            break;

        default:
            raise_trap(thread, 0, TT_ILLEGAL_INSTRUCTION, false, false);
            break;
    }
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
            translate_address(thread, thread->scalar_reg[ptr_reg] + offset,
                              &physical_address, false, true);
            break;
        }

        case CC_DTLB_INSERT:
        case CC_ITLB_INSERT:
        {
            uint32_t virtual_address = ROUND_TO_PAGE(thread->scalar_reg[ptr_reg]);
            uint32_t phys_addr_reg = extract_unsigned_bits(instruction, 5, 5);
            uint32_t phys_addr_and_flags = thread->scalar_reg[phys_addr_reg];
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
            uint32_t virtual_address = ROUND_TO_PAGE(thread->scalar_reg[ptr_reg] + offset);
            uint32_t tlb_index = ((virtual_address / PAGE_SIZE) % TLB_SETS) * TLB_WAYS;

            if (!thread->enable_supervisor)
            {
                raise_trap(thread, 0, TT_PRIVILEGED_OP, false, false);
                return;
            }

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

            if (!thread->enable_supervisor)
            {
                raise_trap(thread, 0, TT_PRIVILEGED_OP, false, false);
                return;
            }

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

    instruction = *UINT32_PTR(thread->core->proc->memory, physical_pc);
    thread->core->proc->total_instructions++;

restart:
    if ((instruction & 0xe0000000) == 0xc0000000)
        execute_register_arith_inst(thread, instruction);
    else if ((instruction & 0x80000000) == 0)
    {
        if (instruction == BREAKPOINT_INST)
        {
            struct breakpoint *breakpoint = lookup_breakpoint(thread->core->proc, thread->pc - 4);
            if (breakpoint == NULL)
            {
                // We use a special instruction (which is invalid) to trigger
                // breakpoint lookup. This is an optimization to avoid doing
                // a lookup on every instruction. In this case, the special
                // instruction was already in the program, so raise a fault.
                raise_trap(thread, 0, TT_ILLEGAL_INSTRUCTION, false, false);
                return true;
            }

            // The restart flag indicates we must step past a breakpoint we
            // just hit. Substitute the original instruction.
            if (breakpoint->restart || thread->core->proc->single_stepping)
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
                thread->pc -= 4;    // Reset PC to instruction that trapped.
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

static void timer_tick(struct processor *proc)
{
    if (proc->current_timer_count > 0)
    {
        if (proc->current_timer_count-- == 1)
            raise_interrupt(proc, INT_TIMER);
    }
}
