//
// Copyright (C) 2014 Jeff Bush
// 
// This library is free software; you can redistribute it and/or
// modify it under the terms of the GNU Library General Public
// License as published by the Free Software Foundation; either
// version 2 of the License, or (at your option) any later version.
// 
// This library is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
// Library General Public License for more details.
// 
// You should have received a copy of the GNU Library General Public
// License along with this library; if not, write to the
// Free Software Foundation, Inc., 51 Franklin St, Fifth Floor,
// Boston, MA  02110-1301, USA.
//

`ifndef __DEFINES_V
`define __DEFINES_V

// Configurable parameters

`define THREADS_PER_CORE 4
`define VECTOR_LANES 16
`define CACHE_LINE_BYTES 64	// XXX this must currently be equal to VECTOR_LANES * 4

///////////////////////////////
 
 
//
// Execution pipeline defines
//

typedef logic[31:0] scalar_t;
typedef logic[`VECTOR_LANES - 1:0][31:0] vector_t;
typedef logic[$clog2(`THREADS_PER_CORE) - 1:0] thread_idx_t;
typedef logic[4:0] register_idx_t;
typedef logic[$clog2(`VECTOR_LANES) - 1:0] subcycle_t;

`define NOP 0
`define REG_LINK (register_idx_t'(30))
`define REG_PC (register_idx_t'(31))

// A/B instruction opcodes
typedef enum logic[5:0] {
	OP_OR			= 6'b000000,
	OP_AND			= 6'b000001,
	OP_UMINUS		= 6'b000010,
	OP_XOR			= 6'b000011,
	OP_IADD			= 6'b000101,
	OP_ISUB			= 6'b000110,
	OP_IMUL			= 6'b000111,	
	OP_ASR			= 6'b001001,	// Arithmetic shift right (sign extend)
	OP_LSR			= 6'b001010,	// Logical shift right (no sign extend)
	OP_LSL			= 6'b001011,	// Logical shift left
	OP_CLZ			= 6'b001100,	// Count leading zeroes
	OP_SHUFFLE		= 6'b001101,
	OP_CTZ			= 6'b001110,	// Count trailing zeroes
	OP_COPY			= 6'b001111,
	OP_EQUAL		= 6'b010000,
	OP_NEQUAL		= 6'b010001,
	OP_SIGTR		= 6'b010010,	// Integer greater (signed)
	OP_SIGTE		= 6'b010011,	// Integer greater or equal (signed)
	OP_SILT			= 6'b010100,	// Integer less than (signed)
	OP_SILTE		= 6'b010101,	// Integer less than or equal (signed)
	OP_UIGTR		= 6'b010110,	// Integer greater than (unsigned)
	OP_UIGTE		= 6'b010111,	// Integer greater or equal (unsigned)
	OP_UILT			= 6'b011000,	// Integer less than (unsigned)
	OP_UILTE		= 6'b011001,	// Integer less than or equal (unsigned)
	OP_GETLANE		= 6'b011010,	// getlane
	OP_FTOI			= 6'b011011,
	OP_RECIP		= 6'b011100,	// reciprocal estimate
	OP_SEXT8		= 6'b011101,	
	OP_SEXT16		= 6'b011110,
	OP_FADD			= 6'b100000,
	OP_FSUB			= 6'b100001,
	OP_FGTR			= 6'b101100,	// Floating point greater than
	OP_FLT			= 6'b101110,	// Floating point less than
	OP_FGTE			= 6'b101101,	// Floating point greater or equal
	OP_FLTE			= 6'b101111,	// Floating point less than or equal
	OP_FMUL			= 6'b100010,
	OP_ITOF			= 6'b101010
} alu_op_t;

// Instruction format C operation types
typedef enum logic[3:0] {
	MEM_B 			= 4'b0000,		// Byte (8 bit)
	MEM_BX 			= 4'b0001,		// Byte, sign extended
	MEM_S 			= 4'b0010,		// Short (16 bit)
	MEM_SX			= 4'b0011,		// Short, sign extended
	MEM_L			= 4'b0100,		// Long (32 bit)
	MEM_SYNC		= 4'b0101,		// Synchronized
	MEM_CONTROL_REG	= 4'b0110,		// Control register
	MEM_BLOCK		= 4'b0111,		// Vector block
	MEM_BLOCK_M		= 4'b1000,
	MEM_BLOCK_IM	= 4'b1001,
	MEM_STRIDED		= 4'b1010,		// Vector strided
	MEM_STRIDED_M	= 4'b1011,
	MEM_STRIDED_IM	= 4'b1100,
	MEM_SCGATH		= 4'b1101,		// Vector scatter/gather
	MEM_SCGATH_M	= 4'b1110,
	MEM_SCGATH_IM	= 4'b1111
} fmtc_op_t;

// Instruction format D operation types
typedef enum logic[2:0] {
	CACHE_DPRELOAD		= 3'b000,
	CACHE_DINVALIDATE 	= 3'b001,
	CACHE_DFLUSH		= 3'b010,
	CACHE_IINVALIDATE	= 3'b011,
	CACHE_STBAR			= 3'b100
} fmtd_op_t;

// Instruction format E operation types
typedef enum logic[2:0] {
	BRANCH_ALL           = 3'b000,
	BRANCH_ZERO          = 3'b001,
	BRANCH_NOT_ZERO	     = 3'b010,
	BRANCH_ALWAYS        = 3'b011,
	BRANCH_CALL_OFFSET   = 3'b100,
	BRANCH_NOT_ALL       = 3'b101,
	BRANCH_CALL_REGISTER = 3'b110
} branch_type_t;

typedef enum logic [2:0] {
	MASK_SRC_SCALAR1,
	MASK_SRC_SCALAR1_INV,
	MASK_SRC_SCALAR2,
	MASK_SRC_SCALAR2_INV,
	MASK_SRC_ALL_ONES
} mask_src_t;

typedef enum logic [1:0] {
	OP2_SRC_SCALAR2,
	OP2_SRC_VECTOR2,
	OP2_SRC_IMMEDIATE
} op2_src_t;

typedef enum logic [1:0] {
	PIPE_MEM,
	PIPE_SCYCLE_ARITH,
	PIPE_MCYCLE_ARITH
} pipeline_sel_t;

typedef enum logic [4:0] {
	CR_STRAND_ID = 5'd0,
	CR_HALT_STRAND = 5'd29,
	CR_STRAND_ENABLE = 5'd30,
	CR_HALT = 5'd31
} control_register_t;

typedef struct packed {
	scalar_t pc;
	logic invalid_instr;
	logic has_scalar1;
	register_idx_t scalar_sel1;
	logic has_scalar2;
	register_idx_t scalar_sel2;
	logic has_vector1;
	register_idx_t vector_sel1;
	logic has_vector2;
	register_idx_t vector_sel2;
	logic has_dest;
	logic dest_is_vector;
	register_idx_t dest_reg;
	alu_op_t alu_op;
	mask_src_t mask_src;
	logic op1_is_vector;
	op2_src_t op2_src;
	logic store_value_is_vector;
	scalar_t immediate_value;
	logic is_branch;
	branch_type_t branch_type;
	pipeline_sel_t pipeline_sel;
	logic is_memory_access;
	fmtc_op_t memory_access_type;
	logic is_load;
	logic is_compare;
	subcycle_t last_subcycle;
	control_register_t creg_index;  
} decoded_instruction_t;

typedef struct packed {
	logic sign;
	logic[7:0] exponent;
	logic[22:0] significand;
} ieee754_binary32_t;

//
// Cache defines
//

`define CACHE_LINE_BITS (`CACHE_LINE_BYTES * 8)
`define CACHE_LINE_WORDS (`CACHE_LINE_BYTES / 4)
`define CACHE_LINE_OFFSET_WIDTH $clog2(`CACHE_LINE_BYTES)

`define L1D_WAYS 4	// XXX Currently the LRU implementation fixes at 4
`define L1D_SETS 32

typedef logic[$clog2(`L1D_WAYS) - 1:0] l1d_way_idx_t;
typedef logic[$clog2(`L1D_SETS) - 1:0] l1d_set_idx_t;
typedef logic[(31 - (`CACHE_LINE_OFFSET_WIDTH + $clog2(`L1D_SETS))):0] l1d_tag_t;
typedef struct packed {
	l1d_tag_t tag;
	l1d_set_idx_t set_idx;
	logic[`CACHE_LINE_OFFSET_WIDTH - 1:0] offset;
} l1d_addr_t;

`define L1I_WAYS 4 // XXX Currently the LRU implementation fixes at 4
`define L1I_SETS 32

typedef logic[$clog2(`L1I_WAYS) - 1:0] l1i_way_idx_t;
typedef logic[$clog2(`L1I_SETS) - 1:0] l1i_set_idx_t;
typedef logic[(31 - (`CACHE_LINE_OFFSET_WIDTH + $clog2(`L1I_SETS))):0] l1i_tag_t;
typedef struct packed {
	l1i_tag_t tag;
	l1i_set_idx_t set_idx;
	logic[`CACHE_LINE_OFFSET_WIDTH - 1:0] offset;
} l1i_addr_t;

typedef enum logic[2:0] {
	PM_WRITE_PENDING,
	PM_WRITE_SENT,
	PM_READ_PENDING,
	PM_READ_SENT,
	PM_INVALIDATED
} pending_miss_state_t;

typedef enum logic[1:0] {
	CL_STATE_INVALID,
	CL_STATE_SHARED,
	CL_STATE_MODIFIED
} cache_line_state_t;

typedef enum logic[2:0] {
	PKT_READ_SHARED,
	PKT_WRITE_INVALIDATE,
	PKT_L2_WRITEBACK,
	PKT_FLUSH,
	PKT_INVALIDATE
} ring_packet_type_t;

typedef enum logic {
	CT_ICACHE,
	CT_DCACHE
} cache_type_t;

typedef logic[3:0] core_id_t;

typedef struct packed {
	logic valid;
	ring_packet_type_t packet_type;
	logic ack;
	logic l2_miss;
	core_id_t dest_core;
	scalar_t address;
	cache_type_t cache_type;
	logic[`CACHE_LINE_BITS - 1:0] data;
} ring_packet_t;

`endif
