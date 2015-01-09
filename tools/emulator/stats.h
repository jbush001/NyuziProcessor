// 
// Copyright (C) 2014 Jeff Bush
// 
// This program is free software; you can redistribute it and/or
// modify it under the terms of the GNU General Public License
// as published by the Free Software Foundation; either version 2
// of the License, or (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program; if not, write to the Free Software
// Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
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

