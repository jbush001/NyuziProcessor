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

#ifndef __INSTRUCTION_SET_H
#define __INSTRUCTION_SET_H

#define LINK_REG 30
#define PC_REG 31
#define INSTRUCTION_NOP 0

#define TLB_WRITE_ENABLE 2

enum _ArithmeticOp
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
	OP_CMPNE_F = 49	
};
typedef enum _ArithmeticOp ArithmeticOp;

enum _RegisterArithFormat
{
	FMT_RA_SS = 0,
	FMT_RA_VS = 1,
	FMT_RA_VS_M = 2,
	FMT_RA_VV = 4,
	FMT_RA_VV_M = 5
};
typedef enum _RegisterArithFormat RegisterArithFormat;

enum _ImmediateArithFormat
{
	FMT_IMM_SS = 0,
	FMT_IMM_VV = 1,
	FMT_IMM_VV_M = 2,
	FMT_IMM_VS = 4,
	FMT_IMM_VS_M = 5
};
typedef enum _ImmediateArithFormat ImmediateArithFormat;

enum _MemoryOp
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
typedef enum _MemoryOp MemoryOp;

enum _BranchType
{
	BRANCH_ALL = 0,
	BRANCH_ZERO = 1,
	BRANCH_NOT_ZERO = 2,
	BRANCH_ALWAYS = 3,
	BRANCH_CALL_OFFSET = 4,
	BRANCH_NOT_ALL = 5,
	BRANCH_CALL_REGISTER = 6,
	BRANCH_ERET = 7
};
typedef enum _BranchType BranchType;

enum _ControlRegister {
	CR_THREAD_ID = 0,
	CR_FAULT_HANDLER = 1,
	CR_FAULT_PC = 2,
	CR_FAULT_REASON = 3,
	CR_FLAGS = 4,
	CR_FAULT_ADDRESS = 5,
	CR_CYCLE_COUNT = 6,
	CR_TLB_MISS_HANDLER = 7,
	CR_SAVED_FLAGS = 8,
	CR_SCRATCHPAD0 = 11,
	CR_SCRATCHPAD1 = 12,
	CR_SUBCYCLE = 13
};
typedef enum _ControlRegister ControlRegister;

enum _FaultReason
{
	FR_RESET,
	FR_ILLEGAL_INSTRUCTION,
	FR_ALIGNMENT_FAULT,
	FR_INTERRUPT,
	FR_IFETCH_FAULT,
	FR_ITLB_MISS,
	FR_DTLB_MISS,
	FR_ILLEGAL_WRITE
};
typedef enum _FaultReason FaultReason;

enum _CacheControlOp
{
	CC_DTLB_INSERT = 0,
	CC_INVALIDATE_TLB = 5,
	CC_INVALIDATE_TLB_ALL = 6,
	CC_ITLB_INSERT = 7
};
typedef enum _CacheControlOp CacheControlOp;

#endif
