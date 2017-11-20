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

#ifndef COSIMULATION_H
#define COSIMULATION_H

#include "processor.h"

// Execute code in cosimulation until the processor halts.
// This reads events from standard in and calls into the core emulator loop to
// step each emulator thread in lockstep, ensuring the side effects match.
// Returns -1 if there is a mismatch between the hardware implementation and
// emulator, 0 if they matched.
int run_cosimulation(struct processor*, bool verbose);

// These functions are called by the emulator loop as a side effect of executing
// emulated instrucitons. The emulator compares these actions to the hardware actions
// read from stdin.
void cosim_check_set_scalar_reg(struct processor*, uint32_t pc, uint32_t reg, uint32_t value);
void cosim_check_set_vector_reg(struct processor*, uint32_t pc, uint32_t reg, uint32_t mask,
                                const uint32_t *value);
void cosim_check_vector_store(struct processor*, uint32_t pc, uint32_t address, uint32_t mask,
                              const uint32_t *values);
void cosim_check_scalar_store(struct processor*, uint32_t pc, uint32_t address, uint32_t size,
                              uint32_t value);

#endif
