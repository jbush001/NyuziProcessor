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



#ifndef __STATS_H
#define __STATS_H

#include <stdint.h>

typedef enum 
{
    STAT_VECTOR_INST,
    STAT_LOAD_INST,
    STAT_STORE_INST,
    STAT_BRANCH_INST,
    STAT_IMM_ARITH_INST,
    STAT_REG_ARITH_INST,
    MAX_STAT_TYPES
} InstructionType;

#ifdef LOG_INSTRUCTIONS
    #define LOG_INST_TYPE(type) __logInstruction(type)
#else
    #define LOG_INST_TYPE(type) do { } while (0)
#endif

#define INC_INST_COUNT __total_instructions++;

void __logInstruction(InstructionType type);
void dumpInstructionStats();
extern int64_t __total_instructions;

#endif

