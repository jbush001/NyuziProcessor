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

#ifndef __CORE_H
#define __CORE_H

#include <stdbool.h>
#include <stdint.h>

#define NUM_REGISTERS 32
#define NUM_VECTOR_LANES 16
#define ALL_THREADS 0xffffffff
#define CACHE_LINE_LENGTH 64u
#define CACHE_LINE_MASK (CACHE_LINE_LENGTH - 1)

struct core *init_core(uint32_t memsize, uint32_t total_threads, bool randomize_memory,
                       const char *shared_memory_file);
void enable_tracing(struct core*);
int load_hex_file(struct core*, const char *filename);
void write_memory_to_file(const struct core*, const char *filename, uint32_t base_address,
                          uint32_t length);
const void *get_memory_region_ptr(const struct core*, uint32_t address, uint32_t length);
void print_registers(const struct core*, uint32_t thread_id);
void enable_cosimulation(struct core*);
void raise_interrupt(struct core*, uint32_t int_bitmap);
void cosim_interrupt(struct core*, uint32_t thread_id, uint32_t pc);
uint32_t get_total_threads(const struct core*);
bool core_halted(const struct core*);
bool stopped_on_fault(const struct core*);

// Return false if this hit a breakpoint or crashed
// thread_id of ALL_THREADS means run all threads in a round robin fashion.
// Otherwise, run just the indicated thread.
bool execute_instructions(struct core*, uint32_t thread_id, uint64_t instructions);

void single_step(struct core*, uint32_t thread_id);
uint32_t get_pc(const struct core*, uint32_t thread_id);
uint32_t get_scalar_register(const struct core*, uint32_t thread_id, uint32_t reg_id);
uint32_t get_vector_register(const struct core*, uint32_t thread_id, uint32_t reg_id, uint32_t lane);
uint32_t debug_read_memory_byte(const struct core*, uint32_t addr);
void debug_write_memory_byte(const struct core*, uint32_t addr, uint8_t byte);
int set_breakpoint(struct core*, uint32_t pc);
int clear_breakpoint(struct core*, uint32_t pc);
void set_stop_on_fault(struct core*, bool stop_on_fault);

void dump_instruction_stats(struct core*);

#endif
