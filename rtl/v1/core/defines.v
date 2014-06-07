// 
// Copyright (C) 2011-2014 Jeff Bush
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

////////////////////////////////////////////////////////////////////
// Configurable parameters
////////////////////////////////////////////////////////////////////

`define NUM_CORES 1	// Can currently only be 1 or 2

`define STRANDS_PER_CORE 4

// Each set is 256 bytes (4 ways * 64 byte lines).  The total size
// of caches can be controlled by altering these.  These must be a power
// of two.
`define L1_NUM_SETS 64   // 16k
`define L2_NUM_SETS 256  // 64k

// If this is not set, thread scheduler will switch on stall.
`define BARREL_SWITCH 1

`define VECTOR_LANES 16

`define AXI_DATA_WIDTH 32


////////////////////////////////////////////////////////////////////
// Constants
////////////////////////////////////////////////////////////////////

// XXX Note that the cache line must be the same size as a vector register currently
`define CACHE_LINE_BYTES 64
`define CACHE_LINE_WORDS (`CACHE_LINE_BYTES / 4)
`define CACHE_LINE_BITS (`CACHE_LINE_BYTES * 8)
`define CACHE_LINE_OFFSET_BITS $clog2(`CACHE_LINE_BYTES)

// The L2 cache directory mirrors the configuration of the L1 caches to
// maintain coherence, so these are defined globally instead of with
// parameters
// NOTE: the number of ways is hard coded in a number of spots.  Changing it
// here would break things without fixing those.
//
`define L1_NUM_WAYS 4
`define L1_SET_INDEX_WIDTH $clog2(`L1_NUM_SETS)
`define L1_WAY_INDEX_WIDTH $clog2(`L1_NUM_WAYS)
`define L1_TAG_WIDTH (32 - `L1_SET_INDEX_WIDTH - `CACHE_LINE_OFFSET_BITS)	

// L2 cache
`define L2_NUM_WAYS 4
`define L2_SET_INDEX_WIDTH $clog2(`L2_NUM_SETS)
`define L2_WAY_INDEX_WIDTH $clog2(`L2_NUM_WAYS)
`define L2_TAG_WIDTH (32 - `L2_SET_INDEX_WIDTH - `CACHE_LINE_OFFSET_BITS)
`define L2_CACHE_ADDR_WIDTH (`L2_SET_INDEX_WIDTH + `L2_WAY_INDEX_WIDTH)

`define CORE_INDEX_WIDTH (`NUM_CORES > 1 ? $clog2(`NUM_CORES) : 1)
`define STRAND_INDEX_WIDTH $clog2(`STRANDS_PER_CORE)

// This is the total register index width, which includes the strand ID
`define REG_IDX_WIDTH (5 + `STRAND_INDEX_WIDTH)

`define VECTOR_BITS (`VECTOR_LANES * 32)

typedef enum logic [1:0] {
	UNIT_ICACHE = 2'd0,
	UNIT_DCACHE = 2'd1,
	UNIT_STBUF = 2'd2
} unit_id_t;

typedef enum logic [2:0] {
	L2REQ_LOAD = 3'b000,
	L2REQ_STORE = 3'b001,
	L2REQ_FLUSH = 3'b010,
	L2REQ_DINVALIDATE = 3'b011,
	L2REQ_LOAD_SYNC = 3'b100,
	L2REQ_STORE_SYNC = 3'b101,
	L2REQ_IINVALIDATE = 3'b110
} l2req_packet_type_t;

typedef struct packed {
	logic valid;
	logic [`CORE_INDEX_WIDTH - 1:0] core;
	unit_id_t unit;
	logic [`STRAND_INDEX_WIDTH - 1:0] strand;
	l2req_packet_type_t op;
	logic [`L1_WAY_INDEX_WIDTH - 1:0] way;
	logic [25:0] address;
	logic [`CACHE_LINE_BYTES - 1:0] mask;
	logic [`CACHE_LINE_BITS - 1:0] data;
} l2req_packet_t;

typedef enum logic [1:0] {
	L2RSP_LOAD_ACK = 2'b00,
	L2RSP_STORE_ACK = 2'b01,
	L2RSP_DINVALIDATE = 2'b10,
	L2RSP_IINVALIDATE = 2'b11
} l2rsp_packet_type_t;

typedef struct packed {
	logic valid;
	logic status;
	logic[`CORE_INDEX_WIDTH - 1:0] core;
	unit_id_t unit;
	logic[`STRAND_INDEX_WIDTH - 1:0] strand;
	l2rsp_packet_type_t op;
	logic[`NUM_CORES - 1:0] update;
	logic[`NUM_CORES * `L1_WAY_INDEX_WIDTH - 1:0] way;
	logic[25:0] address;
	logic[`CACHE_LINE_BITS - 1:0] data;
} l2rsp_packet_t;

////////////////////////////////////////////////////////////////////
// Constants used in various fields in instructions
////////////////////////////////////////////////////////////////////
`define NOP				32'd0

`define REG_PC			5'd31
`define REG_LINK		5'd30

// Instruction format A operation types
typedef enum logic[2:0] {
	FMTA_S      = 3'b000,
	FMTA_V_S    = 3'b001,
	FMTA_V_S_M  = 3'b010,
	FMTA_V_V    = 3'b100,
	FMTA_V_V_M  = 3'b101
} a_fmt_t;

// Instruction format B operation types (first param is dest type, second is first src)
typedef enum logic[2:0] {
	FMTB_S_S      = 3'b000,
	FMTB_V_V      = 3'b001,
	FMTB_V_V_M    = 3'b010,
	FMTB_V_S      = 3'b100,
	FMTB_V_S_M    = 3'b101
} b_fmt_t;

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
} arith_opcode_t;

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
	MEM_SCGATH		= 4'b1101,		// Vector scatter/gather
	MEM_SCGATH_M	= 4'b1110
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

// Control registers
typedef enum logic [4:0] {
	CR_STRAND_ID = 5'd0,
	CR_EXCEPTION_HANDLER = 5'd1,
	CR_FAULT_ADDRESS = 5'd2,
	CR_HALT_STRAND = 5'd29,
	CR_STRAND_ENABLE = 5'd30,
	CR_HALT = 5'd31
} control_register_t;

interface axi_interface;
	// Write address channel                  Source
	logic [31:0]                  awaddr;   // master
	logic [7:0]                   awlen;    // master
	logic                         awvalid;  // master
	logic                         awready;  // slave

	// Write data channel
	logic [`AXI_DATA_WIDTH - 1:0] wdata;    // master
	logic                         wlast;    // master
	logic                         wvalid;   // master
	logic                         wready;   // slave

	// Write response channel
	logic                         bvalid;   // slave
	logic                         bready;   // master

	// Read address channel
	logic [31:0]                  araddr;   // master
	logic [7:0]                   arlen;    // master
	logic                         arvalid;  // master
	logic                         arready;  // slave
	
	// Read data channel
	logic                         rready;   // master
	logic                         rvalid;   // slave
	logic [`AXI_DATA_WIDTH - 1:0] rdata;    // slave
endinterface

////////////////////////////////////////////////////////////////////
// Constants in decode stage output signals
////////////////////////////////////////////////////////////////////

typedef enum logic[1:0] {
	MASK_SRC_SCALAR1 = 2'b00,
	MASK_SRC_SCALAR2 = 2'b01,
	MASK_SRC_ALL_ONES = 2'b11
} mask_src_t;

typedef enum logic[1:0] {
	OP2_SRC_SCALAR2 = 2'b00,
	OP2_SRC_VECTOR2 = 2'b01,
	OP2_SRC_IMMEDIATE = 2'b10
} op2_src_t;

// Floating point constants
`define FP_EXPONENT_WIDTH 8
`define FP_SIGNIFICAND_WIDTH 23


`endif
