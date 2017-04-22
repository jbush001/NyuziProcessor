//
// Copyright 2015 Jeff Bush
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

#ifndef INSTRUCTION_SET_H
#define INSTRUCTION_SET_H

#define LINK_REG 31
#define INSTRUCTION_NOP 0

#define TLB_PRESENT 1
#define TLB_WRITE_ENABLE 2
#define TLB_EXECUTABLE 4
#define TLB_SUPERVISOR 8
#define TLB_GLOBAL 16

enum arithmetic_op
{
    OP_OR = 0,
    OP_AND = 1,
    OP_XOR = 3,
    OP_ADD_I = 5,
    OP_SUB_I = 6,
    OP_MULL_I = 7,
    OP_MULH_U = 8,
    OP_ASHR = 9,
    OP_SHR = 10,
    OP_SHL = 11,
    OP_CLZ = 12,
    OP_SHUFFLE = 13,
    OP_CTZ = 14,
    OP_MOVE	= 15,
    OP_CMPEQ_I = 16,
    OP_CMPNE_I = 17,
    OP_CMPGT_I = 18,
    OP_CMPGE_I = 19,
    OP_CMPLT_I = 20,
    OP_CMPLE_I = 21,
    OP_CMPGT_U = 22,
    OP_CMPGE_U = 23,
    OP_CMPLT_U = 24,
    OP_CMPLE_U = 25,
    OP_GETLANE = 26,
    OP_FTOI = 27,
    OP_RECIPROCAL = 28,
    OP_SEXT8 = 29,
    OP_SEXT16 = 30,
    OP_MULH_I = 31,
    OP_ADD_F = 32,
    OP_SUB_F = 33,
    OP_MUL_F = 34,
    OP_ITOF	= 42,
    OP_CMPGT_F = 44,
    OP_CMPGE_F = 45,
    OP_CMPLT_F = 46,
    OP_CMPLE_F = 47,
    OP_CMPEQ_F = 48,
    OP_CMPNE_F = 49,
    OP_BREAKPOINT = 62,
    OP_SYSCALL = 63
};

enum register_arith_format
{
    FMT_RA_SS = 0,
    FMT_RA_VS = 1,
    FMT_RA_VS_M = 2,
    FMT_RA_VV = 4,
    FMT_RA_VV_M = 5
};

enum immediate_arith_format
{
    FMT_IMM_S = 0,
    FMT_IMM_V = 1,
    FMT_IMM_MOVEHI = 2,
    FMT_IMM_VM = 3,
};

enum memory_op
{
    MEM_BYTE = 0,
    MEM_BYTE_SEXT = 1,
    MEM_SHORT = 2,
    MEM_SHORT_EXT = 3,
    MEM_LONG = 4,
    MEM_SYNC = 5,
    MEM_CONTROL_REG = 6,
    MEM_BLOCK_VECTOR = 7,
    MEM_BLOCK_VECTOR_MASK = 8,
    MEM_SCGATH = 13,
    MEM_SCGATH_MASK = 14
};

enum branch_type
{
    BRANCH_REGISTER = 0,
    BRANCH_ZERO = 1,
    BRANCH_NOT_ZERO = 2,
    BRANCH_ALWAYS = 3,
    BRANCH_CALL_OFFSET = 4,
    BRANCH_CALL_REGISTER = 6,
    BRANCH_ERET = 7
};

enum control_register
{
    CR_THREAD_ID = 0,
    CR_TRAP_HANDLER = 1,
    CR_TRAP_PC = 2,
    CR_TRAP_REASON = 3,
    CR_FLAGS = 4,
    CR_TRAP_ACCESS_ADDR = 5,
    CR_CYCLE_COUNT = 6,
    CR_TLB_MISS_HANDLER = 7,
    CR_SAVED_FLAGS = 8,
    CR_CURRENT_ASID = 9,
    CR_PAGE_DIR = 10,
    CR_SCRATCHPAD0 = 11,
    CR_SCRATCHPAD1 = 12,
    CR_SUBCYCLE = 13,
    CR_INTERRUPT_MASK = 14,
    CR_INTERRUPT_ACK = 15,
    CR_INTERRUPT_PENDING = 16,
    CR_INTERRUPT_TRIGGER = 17
};

enum trap_type
{
    TT_RESET = 0,
    TT_ILLEGAL_INSTRUCTION = 1,
    TT_PRIVILEGED_OP = 2,
    TT_INTERRUPT = 3,
    TT_SYSCALL = 4,
    TT_UNALIGNED_ACCESS = 5,
    TT_PAGE_FAULT = 6,
    TT_TLB_MISS = 7,
    TT_ILLEGAL_STORE = 8,
    TT_SUPERVISOR_ACCESS = 9,
    TT_NOT_EXECUTABLE = 10,
    TT_BREAKPOINT = 11
};

enum cache_control_op
{
    CC_DTLB_INSERT = 0,
    CC_DINVALIDATE = 1,
    CC_DFLUSH = 2,
    CC_INVALIDATE_TLB = 5,
    CC_INVALIDATE_TLB_ALL = 6,
    CC_ITLB_INSERT = 7
};

#endif
