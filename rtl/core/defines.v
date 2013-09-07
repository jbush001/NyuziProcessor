// 
// Copyright 2013 Jeff Bush
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
`define L1_NUM_SETS 32	// 8k
`define L2_NUM_SETS 256	// 64k

////////////////////////////////////////////////////////////////////
// L2 cache interface constants
////////////////////////////////////////////////////////////////////

`define L2REQ_LOAD  3'b000
`define L2REQ_STORE 3'b001
`define L2REQ_FLUSH 3'b010
`define L2REQ_DINVALIDATE 3'b011
`define L2REQ_LOAD_SYNC 3'b100
`define L2REQ_STORE_SYNC 3'b101
`define L2REQ_IINVALIDATE 3'b110

`define L2RSP_LOAD_ACK 2'b00
`define L2RSP_STORE_ACK 2'b01
`define L2RSP_DINVALIDATE 2'b10
`define L2RSP_IINVALIDATE 2'b11


`define CACHE_LINE_LENGTH 64
`define CACHE_LINE_OFFSET_BITS $clog2(`CACHE_LINE_LENGTH)

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

// l2req_unit identifiers
`define UNIT_ICACHE 2'd0
`define UNIT_DCACHE 2'd1
`define UNIT_STBUF 2'd2

////////////////////////////////////////////////////////////////////
// Constants used in various fields in instructions
////////////////////////////////////////////////////////////////////
`define NOP				32'd0

`define REG_PC			5'd31
`define REG_LINK		5'd30

// Instruction format A operation types
`define FMTA_S			3'b000
`define FMTA_V_S		3'b001
`define FMTA_V_S_M		3'b010
`define FMTA_V_S_IM		3'b011
`define FMTA_V_V		3'b100
`define FMTA_V_V_M		3'b101
`define FMTA_V_V_IM		3'b110

// Instruction format B operation types (first param is dest type, second is first src)
`define FMTB_S_S		3'b000
`define FMTB_V_V		3'b001
`define FMTB_V_V_M		3'b010
`define FMTB_V_V_IM		3'b011
`define FMTB_V_S		3'b100
`define FMTB_V_S_M		3'b101
`define FMTB_V_S_IM		3'b110

// A/B instruction opcodes
`define OP_OR			6'b000000
`define OP_AND			6'b000001
`define OP_UMINUS		6'b000010
`define OP_XOR			6'b000011
`define OP_NOT			6'b000100
`define OP_IADD			6'b000101
`define OP_ISUB			6'b000110
`define OP_IMUL			6'b000111	
`define OP_ASR			6'b001001	// Arithmetic shift right (sign extend)
`define OP_LSR			6'b001010	// Logical shift right (no sign extend)
`define OP_LSL			6'b001011	// Logical shift left
`define OP_CLZ			6'b001100	// Count leading zeroes
`define OP_SHUFFLE		6'b001101
`define OP_CTZ			6'b001110	// Count trailing zeroes
`define OP_COPY			6'b001111
`define OP_EQUAL		6'b010000
`define OP_NEQUAL		6'b010001
`define OP_SIGTR		6'b010010	// Integer greater (signed)
`define OP_SIGTE		6'b010011	// Integer greater or equal (signed)
`define OP_SILT			6'b010100	// Integer less than (signed)
`define OP_SILTE		6'b010101	// Integer less than or equal (signed)
`define OP_UIGTR		6'b010110	// Integer greater than (unsigned)
`define OP_UIGTE		6'b010111	// Integer greater or equal (unsigned)
`define OP_UILT			6'b011000	// Integer less than (unsigned)
`define OP_UILTE		6'b011001	// Integer less than or equal (unsigned)
`define OP_GETLANE		6'b011010	// getlane
`define OP_FTOI			6'b011011
`define OP_RECIP		6'b011100	// reciprocal estimate
`define OP_SEXT8		6'b011101	
`define OP_SEXT16		6'b011110
`define OP_FADD			6'b100000
`define OP_FSUB			6'b100001
`define OP_FGTR			6'b101100	// Floating point greater than
`define OP_FLT			6'b101110	// Floating point less than
`define OP_FGTE			6'b101101	// Floating point greater or equal
`define OP_FLTE			6'b101111	// Floating point less than or equal
`define OP_FMUL			6'b100010
`define OP_ITOF			6'b101010

// Instruction format C operation types
`define MEM_B 			4'b0000		// Byte (8 bit)
`define MEM_BX 			4'b0001		// Byte, sign extended
`define MEM_S 			4'b0010		// Short (16 bit)
`define MEM_SX			4'b0011		// Short, sign extended
`define MEM_L			4'b0100		// Long (32 bit)
`define MEM_SYNC		4'b0101		// Synchronized
`define MEM_CONTROL_REG	4'b0110		// Control register
`define MEM_BLOCK		4'b0111		// Vector block
`define MEM_BLOCK_M		4'b1000
`define MEM_BLOCK_IM	4'b1001
`define MEM_STRIDED		4'b1010		// Vector strided
`define MEM_STRIDED_M	4'b1011
`define MEM_STRIDED_IM	4'b1100
`define MEM_SCGATH		4'b1101		// Vector scatter/gather
`define MEM_SCGATH_M	4'b1110
`define MEM_SCGATH_IM	4'b1111

// Instruction format D operation types
`define CACHE_DPRELOAD		3'b000
`define CACHE_DINVALIDATE 	3'b001
`define CACHE_DFLUSH		3'b010
`define CACHE_IINVALIDATE	3'b011
`define CACHE_STBAR			3'b100

// Instruction format E operation types
`define BRANCH_ALL			3'b000
`define BRANCH_ZERO			3'b001
`define BRANCH_NOT_ZERO		3'b010
`define BRANCH_ALWAYS		3'b011
`define BRANCH_CALL_OFFSET 	3'b100
`define BRANCH_NOT_ALL		3'b101
`define BRANCH_CALL_REGISTER 3'b110

// Control registers
`define CR_STRAND_ID 0
`define CR_EXCEPTION_HANDLER 1
`define CR_FAULT_ADDRESS 2
`define CR_HALT_STRAND 29
`define CR_STRAND_ENABLE 30
`define CR_HALT 31

////////////////////////////////////////////////////////////////////
// Constants in decode stage output signals
////////////////////////////////////////////////////////////////////

`define MASK_SRC_SCALAR1 		3'b000
`define MASK_SRC_SCALAR1_INV 	3'b001
`define MASK_SRC_SCALAR2		3'b010
`define MASK_SRC_SCALAR2_INV	3'b011
`define MASK_SRC_ALL_ONES		3'b100

`define OP2_SRC_SCALAR2			2'b00
`define OP2_SRC_VECTOR2			2'b01
`define OP2_SRC_IMMEDIATE		2'b10

// Floating point constants
`define FP_EXPONENT_WIDTH 8
`define FP_SIGNIFICAND_WIDTH 23

`endif