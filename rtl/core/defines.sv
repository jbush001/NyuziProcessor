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


`ifndef __DEFINES_V
`define __DEFINES_V

// Configurable parameters
// Number of ways must be 1, 2, 4, or 8

`define NUM_CORES 1
`define THREADS_PER_CORE 4
`define L1D_WAYS 4
`define L1D_SETS 64		// 16k
`define L1I_WAYS 4
`define L1I_SETS 64		// 16k
`define L2_WAYS 8
`define L2_SETS 256		// 128k
`define AXI_DATA_WIDTH 32

///////////////////////////////

//
// Execution pipeline defines
//

`define VECTOR_LANES 16
`define NUM_REGISTERS 32

typedef logic[31:0] scalar_t;
typedef scalar_t[`VECTOR_LANES - 1:0] vector_t;
typedef logic[$clog2(`THREADS_PER_CORE) - 1:0] thread_idx_t;
typedef logic[`THREADS_PER_CORE - 1:0] thread_bitmap_t;	// One bit per thread
typedef logic[4:0] register_idx_t;
typedef logic[$clog2(`VECTOR_LANES) - 1:0] subcycle_t;
typedef logic[`VECTOR_LANES - 1:0] vector_lane_mask_t;

`define NOP 32'd0
`define REG_RA (register_idx_t'(30))
`define REG_PC (register_idx_t'(31))

`define RESET_PC 0

// Immediate/register arithmetic
typedef enum logic[5:0] {
	OP_OR			= 6'b000000,
	OP_AND			= 6'b000001,
	OP_XOR			= 6'b000011,
	OP_ADD_I		= 6'b000101,
	OP_SUB_I		= 6'b000110,
	OP_MULL_I		= 6'b000111,	// Multiply low	
	OP_MULH_U		= 6'b001000,	// Unsigned multiply high 
	OP_ASHR			= 6'b001001,	// Arithmetic shift right (sign extend)
	OP_SHR			= 6'b001010,	// Logical shift right (no sign extend)
	OP_SHL			= 6'b001011,	// Logical shift left
	OP_CLZ			= 6'b001100,	// Count leading zeroes
	OP_SHUFFLE		= 6'b001101,
	OP_CTZ			= 6'b001110,	// Count trailing zeroes
	OP_MOVE			= 6'b001111,
	OP_CMPEQ_I		= 6'b010000,
	OP_CMPNE_I		= 6'b010001,
	OP_CMPGT_I		= 6'b010010,	// Integer greater (signed)
	OP_CMPGE_I		= 6'b010011,	// Integer greater or equal (signed)
	OP_CMPLT_I		= 6'b010100,	// Integer less than (signed)
	OP_CMPLE_I		= 6'b010101,	// Integer less than or equal (signed)
	OP_CMPGT_U		= 6'b010110,	// Integer greater than (unsigned)
	OP_CMPGE_U		= 6'b010111,	// Integer greater or equal (unsigned)
	OP_CMPLT_U		= 6'b011000,	// Integer less than (unsigned)
	OP_CMPLE_U		= 6'b011001,	// Integer less than or equal (unsigned)
	OP_GETLANE		= 6'b011010,	// Getlane
	OP_FTOI			= 6'b011011,
	OP_RECIPROCAL	= 6'b011100,	// Reciprocal estimate
	OP_SEXT8		= 6'b011101,	
	OP_SEXT16		= 6'b011110,
	OP_MULH_I		= 6'b011111,	// Signed multiply high
	OP_ADD_F		= 6'b100000,
	OP_SUB_F		= 6'b100001,
	OP_MUL_F		= 6'b100010,
	OP_ITOF			= 6'b101010,
	OP_CMPGT_F		= 6'b101100,	// Floating point greater than
	OP_CMPLT_F		= 6'b101110,	// Floating point less than
	OP_CMPGE_F		= 6'b101101,	// Floating point greater or equal
	OP_CMPLE_F		= 6'b101111,	// Floating point less than or equal
	OP_CMPEQ_F      = 6'b110000,	// Floating point equal
	OP_CMPNE_F      = 6'b110001		// Floating point not-equal
} alu_op_t;

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
} memory_op_t;

typedef enum logic[2:0] {
	CACHE_DINVALIDATE 	= 3'b001,
	CACHE_DFLUSH		= 3'b010,
	CACHE_IINVALIDATE	= 3'b011,
	CACHE_MEMBAR		= 3'b100
} cache_op_t;

typedef enum logic[2:0] {
	BRANCH_ALL           = 3'b000,
	BRANCH_ZERO          = 3'b001,
	BRANCH_NOT_ZERO	     = 3'b010,
	BRANCH_ALWAYS        = 3'b011,
	BRANCH_CALL_OFFSET   = 3'b100,
	BRANCH_NOT_ALL       = 3'b101,
	BRANCH_CALL_REGISTER = 3'b110,
	BRANCH_ERET          = 3'b111
} branch_type_t;

typedef enum logic [1:0] {
	MASK_SRC_SCALAR1,
	MASK_SRC_SCALAR2,
	MASK_SRC_ALL_ONES
} mask_src_t;

typedef enum logic [1:0] {
	OP1_SRC_VECTOR1,
	OP1_SRC_PC,
	OP1_SRC_SCALAR1
} op1_src_t;

typedef enum logic [1:0] {
	OP2_SRC_SCALAR2,
	OP2_SRC_VECTOR2,
	OP2_SRC_IMMEDIATE,
	OP2_SRC_PC
} op2_src_t;

typedef enum logic [1:0] {
	PIPE_MEM,
	PIPE_SCYCLE_ARITH,
	PIPE_MCYCLE_ARITH
} pipeline_sel_t;

typedef enum logic [4:0] {
	CR_THREAD_ID = 5'd0,
	CR_FAULT_HANDLER = 5'd1,
	CR_FAULT_PC = 5'd2,
	CR_FAULT_REASON = 5'd3,
	CR_FLAGS = 5'd4,	// Maybe stuff some other flags here eventually
	CR_FAULT_ADDRESS = 5'd5,
	CR_CYCLE_COUNT = 5'd6,
	CR_HALT_THREAD = 5'd29,
	CR_THREAD_ENABLE = 5'd30,
	CR_HALT = 5'd31
} control_register_t;

typedef struct packed {
	scalar_t pc;
	logic illegal;
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
	op1_src_t op1_src;
	op2_src_t op2_src;
	logic store_value_is_vector;
	scalar_t immediate_value;
	logic is_branch;
	branch_type_t branch_type;
	pipeline_sel_t pipeline_sel;
	logic is_memory_access;
	memory_op_t memory_access_type;
	logic is_load;
	logic is_compare;
	subcycle_t last_subcycle;
	control_register_t creg_index;  
	logic is_cache_control;
	cache_op_t cache_control_op;
} decoded_instruction_t;

typedef enum logic[3:0] {
	FR_RESET,
	FR_ILLEGAL_INSTRUCTION,
	FR_INVALID_ACCESS,
	FR_INTERRUPT
} fault_reason_t;

typedef struct packed {
	logic sign;
	logic[7:0] exponent;
	logic[22:0] significand;
} ieee754_binary32_t;

//
// Cache defines
//

`define CACHE_LINE_BYTES (`VECTOR_LANES * 4) // Cache line must currently be same as vector width
`define CACHE_LINE_BITS (`CACHE_LINE_BYTES * 8)
`define CACHE_LINE_WORDS (`CACHE_LINE_BYTES / 4)
`define CACHE_LINE_OFFSET_WIDTH $clog2(`CACHE_LINE_BYTES)	// Offset into a cache line

typedef logic[`CACHE_LINE_BITS - 1:0] cache_line_data_t;

typedef logic[$clog2(`L1D_WAYS) - 1:0] l1d_way_idx_t;
typedef logic[$clog2(`L1D_SETS) - 1:0] l1d_set_idx_t;
typedef logic[(31 - (`CACHE_LINE_OFFSET_WIDTH + $clog2(`L1D_SETS))):0] l1d_tag_t;
typedef struct packed {
	l1d_tag_t tag;
	l1d_set_idx_t set_idx;
	logic[`CACHE_LINE_OFFSET_WIDTH - 1:0] offset;
} l1d_addr_t;

typedef logic[$clog2(`L1I_WAYS) - 1:0] l1i_way_idx_t;
typedef logic[$clog2(`L1I_SETS) - 1:0] l1i_set_idx_t;
typedef logic[(31 - (`CACHE_LINE_OFFSET_WIDTH + $clog2(`L1I_SETS))):0] l1i_tag_t;
typedef struct packed {
	l1i_tag_t tag;
	l1i_set_idx_t set_idx;
	logic[`CACHE_LINE_OFFSET_WIDTH - 1:0] offset;
} l1i_addr_t;

typedef logic[$clog2(`L2_WAYS) - 1:0] l2_way_idx_t;
typedef logic[$clog2(`L2_SETS) - 1:0] l2_set_idx_t;
typedef logic[(31 - (`CACHE_LINE_OFFSET_WIDTH + $clog2(`L2_SETS))):0] l2_tag_t;
typedef struct packed {
	l2_tag_t tag;
	l2_set_idx_t set_idx;
	logic[`CACHE_LINE_OFFSET_WIDTH - 1:0] offset;
} l2_addr_t;

// Memory address that is multiple of cache line size
typedef logic[31 - `CACHE_LINE_OFFSET_WIDTH:0] cache_line_index_t;

typedef enum logic {
	CT_ICACHE,
	CT_DCACHE
} cache_type_t;

`define _CORE_ID_WIDTH (`NUM_CORES > 1 ? $clog2(`NUM_CORES) : 1)

typedef logic[`_CORE_ID_WIDTH - 1:0] core_id_t;
typedef logic[$clog2(`THREADS_PER_CORE) - 1:0] l1_miss_entry_idx_t;

typedef enum logic[2:0] {
	L2REQ_LOAD,
	L2REQ_LOAD_SYNC,
	L2REQ_STORE,
	L2REQ_STORE_SYNC,
	L2REQ_FLUSH,
	L2REQ_IINVALIDATE,
	L2REQ_DINVALIDATE
} l2req_packet_type_t;

typedef struct packed {
	logic valid;
	core_id_t core;
	l1_miss_entry_idx_t id;
	l2req_packet_type_t packet_type;
	cache_type_t cache_type;
	scalar_t address;
	logic[`CACHE_LINE_BYTES - 1:0] store_mask;
	cache_line_data_t data;
} l2req_packet_t;

typedef enum logic[2:0] {
	L2RSP_LOAD_ACK,
	L2RSP_STORE_ACK,
	L2RSP_FLUSH_ACK,
	L2RSP_IINVALIDATE_ACK,
	L2RSP_DINVALIDATE_ACK
} l2rsp_packet_type_t;

typedef struct packed {
	logic valid;
	logic status;
	core_id_t core;
	l1_miss_entry_idx_t id;
	l2rsp_packet_type_t packet_type;
	cache_type_t cache_type;
	scalar_t address;
	cache_line_data_t data;
} l2rsp_packet_t;

typedef struct packed {
	logic valid;
	logic is_store;
	thread_idx_t thread_idx;
	scalar_t address;
	scalar_t value;
} ioreq_packet_t;

typedef struct packed {
	logic valid;
	core_id_t core;
	thread_idx_t thread_idx;
	scalar_t read_value;
} iorsp_packet_t;

// AMBA AXI and ACE Protocol Specification, rev E, Table A3-3
typedef enum logic[1:0] {
	AXI_BURST_FIXED = 2'b00,
	AXI_BURST_INCR = 2'b01,
	AXI_BURST_WRAP = 2'b10
} axi_burst_type_t;

// AMBA AXI-4 bus interface
interface axi4_interface;
	// Write address channel (Table A2-2)   
	logic [31:0] m_awaddr;   
	logic [7:0] m_awlen;    
	logic [2:0] m_awsize;
	axi_burst_type_t m_awburst;
	logic [3:0] m_awcache;
	logic m_awvalid;  
	logic s_awready;  

	// Write data channel (Table A2-3)
	logic [`AXI_DATA_WIDTH - 1:0] m_wdata;    
	logic [`AXI_DATA_WIDTH / 8 - 1:0] m_wstrb;
	logic m_wlast;    
	logic m_wvalid;   
	logic s_wready;   

	// Write response channel (Table A2-4)
	logic s_bvalid;   
	logic m_bready;   

	// Read address channel (Table A2-5)
	logic [31:0] m_araddr;   
	logic [7:0] m_arlen;    
	logic [2:0] m_arsize;
	axi_burst_type_t m_arburst;
	logic [3:0] m_arcache;
	logic m_arvalid;  
	logic s_arready;

	// Read data channel (Table A2-6)
	logic [`AXI_DATA_WIDTH - 1:0] s_rdata;    
	logic s_rvalid;   
	logic m_rready;   
	
	modport master(input s_awready, s_wready, s_bvalid, s_arready, s_rvalid, s_rdata,
		output m_awaddr, m_awlen, m_awvalid, m_wdata, m_wlast, m_wvalid, m_bready, m_araddr, m_arlen, 
		m_arvalid, m_rready, m_awsize, m_awburst, m_wstrb, m_arsize, m_arburst, m_awcache, m_arcache);
	modport slave(input m_awaddr, m_awlen, m_awvalid, m_wdata, m_wlast, m_wvalid, m_bready, m_araddr,  
		m_arlen, m_arvalid, m_rready, m_awsize, m_awburst, m_wstrb, m_arsize, m_arburst, 
		m_awcache, m_arcache,
		output s_awready, s_wready, s_bvalid, s_arready, s_rvalid, s_rdata);
endinterface

`endif
