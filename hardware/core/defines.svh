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

`ifndef __DEFINES_SVH
`define __DEFINES_SVH

`include "config.svh"

package defines;

//
// Floating point types
//

parameter FLOAT32_EXP_WIDTH = 8;
parameter FLOAT32_SIG_WIDTH = 23;

// IEEE 754 Binary 32 encoding
typedef struct packed {
    logic sign;
    logic[FLOAT32_EXP_WIDTH - 1:0] exponent;
    logic[FLOAT32_SIG_WIDTH - 1:0] significand;
} float32_t;

//
// Execution pipeline defines
//

parameter NUM_VECTOR_LANES = 16;
parameter NUM_REGISTERS = 32;
parameter TOTAL_THREADS = `THREADS_PER_CORE * `NUM_CORES;

typedef logic[31:0] scalar_t;
typedef scalar_t[NUM_VECTOR_LANES - 1:0] vector_t;
typedef logic[$clog2(`THREADS_PER_CORE) - 1:0] local_thread_idx_t;
typedef logic[`THREADS_PER_CORE - 1:0] local_thread_bitmap_t; // One bit per thread
typedef logic[4:0] register_idx_t;
typedef logic[$clog2(NUM_VECTOR_LANES) - 1:0] subcycle_t;
typedef logic[NUM_VECTOR_LANES - 1:0] vector_mask_t;
typedef logic[14:0] syscall_index_t;

parameter CORE_ID_WIDTH = $clog2(`NUM_CORES);

// The width of core_id_t is hardcoded to work around some tool issues.
// For one core, CORE_ID_WIDTH will be 0, but if I made the range
// [CORE_ID_WIDTH - 1:0], the range would be [-1:0], which is invalid. I tried
// defining CORE_ID_WIDTH as (`NUM_CORES == 1 ? 1 : $clog2(`NUM_CORES)), which
// works fine on many tools, but crashes Synopsys Design Compiler. This limits
// to 16 cores. To synthesize more, increase this width.
// XXX CORE_ID_WIDTH was previously a `define. the workaround above may work
// now that it is a parameter, but I haven't tested.
typedef logic[3:0] core_id_t;

// CORE_PERF_EVENTS should match the number of signals in the assignment to
// core_perf_events in core.sv and L2_PERF_EVENTS must match the number of
// signals in the assignment to l2_perf_events in l2_cache.sv.
parameter CORE_PERF_EVENTS = 14;
parameter L2_PERF_EVENTS = 3;

//
// Instruction encodings
//

parameter INSTRUCTION_NOP = 32'd0;
parameter REG_RA = register_idx_t'(31);

// Immediate/register arithmetic operation encodings
typedef enum logic[5:0] {
    OP_OR                   = 6'b000000,    // Bitwise logical or
    OP_AND                  = 6'b000001,    // bitwise logical and
    OP_SYSCALL              = 6'b000010,    // raise syscall trap
    OP_XOR                  = 6'b000011,    // bitwise logical exclusive or
    OP_ADD_I                = 6'b000101,    // Add integer
    OP_SUB_I                = 6'b000110,    // Subtract integer
    OP_MULL_I               = 6'b000111,    // Multiply integer low
    OP_MULH_U               = 6'b001000,    // Unsigned multiply, return high bits
    OP_ASHR                 = 6'b001001,    // Arithmetic shift right (sign extend)
    OP_SHR                  = 6'b001010,    // Logical shift right (no sign extend)
    OP_SHL                  = 6'b001011,    // Logical shift left
    OP_CLZ                  = 6'b001100,    // Count leading zeroes
    OP_SHUFFLE              = 6'b001101,    // Shuffle vector lanes
    OP_CTZ                  = 6'b001110,    // Count trailing zeroes
    OP_MOVE                 = 6'b001111,
    OP_CMPEQ_I              = 6'b010000,    // Integer equal
    OP_CMPNE_I              = 6'b010001,    // Integer not equal
    OP_CMPGT_I              = 6'b010010,    // Integer greater (signed)
    OP_CMPGE_I              = 6'b010011,    // Integer greater or equal (signed)
    OP_CMPLT_I              = 6'b010100,    // Integer less than (signed)
    OP_CMPLE_I              = 6'b010101,    // Integer less than or equal (signed)
    OP_CMPGT_U              = 6'b010110,    // Integer greater than (unsigned)
    OP_CMPGE_U              = 6'b010111,    // Integer greater or equal (unsigned)
    OP_CMPLT_U              = 6'b011000,    // Integer less than (unsigned)
    OP_CMPLE_U              = 6'b011001,    // Integer less than or equal (unsigned)
    OP_GETLANE              = 6'b011010,    // Getlane
    OP_FTOI                 = 6'b011011,    // Float to integer
    OP_RECIPROCAL           = 6'b011100,    // Reciprocal estimate
    OP_SEXT8                = 6'b011101,    // Sign extend 8 bit value
    OP_SEXT16               = 6'b011110,    // Sign extend 16 bit value
    OP_MULH_I               = 6'b011111,    // Signed multiply high
    OP_ADD_F                = 6'b100000,    // Add floating point
    OP_SUB_F                = 6'b100001,    // Subtract floating point
    OP_MUL_F                = 6'b100010,    // Multiply floating point
    OP_ITOF                 = 6'b101010,    // Integer to float
    OP_CMPGT_F              = 6'b101100,    // Floating point greater than
    OP_CMPLT_F              = 6'b101110,    // Floating point less than
    OP_CMPGE_F              = 6'b101101,    // Floating point greater or equal
    OP_CMPLE_F              = 6'b101111,    // Floating point less than or equal
    OP_CMPEQ_F              = 6'b110000,    // Floating point equal
    OP_CMPNE_F              = 6'b110001,    // Floating point not-equal
    OP_BREAKPOINT           = 6'b111110
} alu_op_t;

// Operation type field encodings for memory instructions
typedef enum logic[3:0] {
    MEM_B                   = 4'b0000,  // Byte (8 bit)
    MEM_BX                  = 4'b0001,  // Byte, sign extended
    MEM_S                   = 4'b0010,  // Short (16 bit)
    MEM_SX                  = 4'b0011,  // Short, sign extended
    MEM_L                   = 4'b0100,  // Long (32 bit)
    MEM_SYNC                = 4'b0101,  // Synchronized
    MEM_CONTROL_REG         = 4'b0110,  // Control register
    MEM_BLOCK               = 4'b0111,  // Vector block
    MEM_BLOCK_M             = 4'b1000,
    MEM_SCGATH              = 4'b1101,  // Vector scatter/gather
    MEM_SCGATH_M            = 4'b1110
} memory_op_t;

// Operation type field encodings for cache control instructions
typedef enum logic[2:0] {
    CACHE_DTLB_INSERT       = 3'b000,
    CACHE_DINVALIDATE       = 3'b001,
    CACHE_DFLUSH            = 3'b010,
    CACHE_IINVALIDATE       = 3'b011,
    CACHE_MEMBAR            = 3'b100,
    CACHE_TLB_INVAL         = 3'b101,
    CACHE_TLB_INVAL_ALL     = 3'b110,
    CACHE_ITLB_INSERT       = 3'b111
} cache_op_t;

// Operation type field encodings for branch instructions
typedef enum logic[2:0] {
    BRANCH_REGISTER         = 3'b000,
    BRANCH_ZERO             = 3'b001,
    BRANCH_NOT_ZERO         = 3'b010,
    BRANCH_ALWAYS           = 3'b011,
    BRANCH_CALL_OFFSET      = 3'b100,
    BRANCH_CALL_REGISTER    = 3'b110,
    BRANCH_ERET             = 3'b111
} branch_type_t;

// Control register indices
typedef enum logic [4:0] {
    CR_THREAD_ID            = 5'd0,
    CR_TRAP_HANDLER         = 5'd1,
    CR_TRAP_PC              = 5'd2,
    CR_TRAP_CAUSE           = 5'd3,
    CR_FLAGS                = 5'd4,
    CR_TRAP_ADDRESS         = 5'd5,
    CR_CYCLE_COUNT          = 5'd6,
    CR_TLB_MISS_HANDLER     = 5'd7,
    CR_SAVED_FLAGS          = 5'd8,
    CR_CURRENT_ASID         = 5'd9,
    CR_PAGE_DIR             = 5'd10,
    CR_SCRATCHPAD0          = 5'd11,
    CR_SCRATCHPAD1          = 5'd12,
    CR_SUBCYCLE             = 5'd13,
    CR_INTERRUPT_ENABLE     = 5'd14,
    CR_INTERRUPT_ACK        = 5'd15,
    CR_INTERRUPT_PENDING    = 5'd16,
    CR_INTERRUPT_TRIGGER    = 5'd17,
    CR_JTAG_DATA            = 5'd18,
    CR_SYSCALL_INDEX        = 5'd19,
    CR_SUSPEND_THREAD       = 5'd20,
    CR_RESUME_THREAD        = 5'd21,
    CR_PERF_EVENT_SELECT0   = 5'd22,
    CR_PERF_EVENT_SELECT1   = 5'd23,
    CR_PERF_EVENT_COUNT0_L  = 5'd24,
    CR_PERF_EVENT_COUNT0_H  = 5'd25,
    CR_PERF_EVENT_COUNT1_L  = 5'd26,
    CR_PERF_EVENT_COUNT1_H  = 5'd27
} control_register_t;

// Trap type encodings
typedef enum logic[3:0] {
    TT_RESET                = 4'd0,
    TT_ILLEGAL_INSTRUCTION  = 4'd1,
    TT_PRIVILEGED_OP        = 4'd2,
    TT_INTERRUPT            = 4'd3,
    TT_SYSCALL              = 4'd4,
    TT_UNALIGNED_ACCESS     = 4'd5,
    TT_PAGE_FAULT           = 4'd6,
    TT_TLB_MISS             = 4'd7,
    TT_ILLEGAL_STORE        = 4'd8,
    TT_SUPERVISOR_ACCESS    = 4'd9,
    TT_NOT_EXECUTABLE       = 4'd10,
    TT_BREAKPOINT           = 4'd11
} trap_type_t;

//
// Decoded instruction fields
//

typedef enum logic [1:0] {
    MASK_SRC_SCALAR1,
    MASK_SRC_SCALAR2,
    MASK_SRC_ALL_ONES
} mask_src_t;

typedef enum logic {
    OP1_SRC_VECTOR1,
    OP1_SRC_SCALAR1
} op1_src_t;

typedef enum logic [1:0] {
    OP2_SRC_SCALAR2,
    OP2_SRC_VECTOR2,
    OP2_SRC_IMMEDIATE
} op2_src_t;

typedef enum logic [1:0] {
    PIPE_MEM,
    PIPE_INT_ARITH,
    PIPE_FLOAT_ARITH
} pipeline_sel_t;

typedef struct packed {
    logic dcache;
    logic store;
    trap_type_t trap_type;
} trap_cause_t;

typedef logic[3:0] interrupt_id_t;

typedef struct packed {
    scalar_t pc;

    // Was this instruction injected by the on-chip debugger
    logic injected;

    // Piggybacked exceptions
    logic has_trap;
    trap_cause_t trap_cause;

    // Decoded instruction fields
    logic has_scalar1;
    register_idx_t scalar_sel1;
    logic has_scalar2;
    register_idx_t scalar_sel2;
    logic has_vector1;
    register_idx_t vector_sel1;
    logic has_vector2;
    register_idx_t vector_sel2;
    logic has_dest;
    logic dest_vector;
    register_idx_t dest_reg;
    alu_op_t alu_op;
    mask_src_t mask_src;
    op1_src_t op1_src;
    op2_src_t op2_src;
    logic store_value_vector;
    scalar_t immediate_value;
    logic branch;
    branch_type_t branch_type;
    logic call;
    pipeline_sel_t pipeline_sel;
    logic memory_access;
    memory_op_t memory_access_type;
    logic load;
    logic compare;
    subcycle_t last_subcycle; // count of last subcycle, not a boolean flag
    control_register_t creg_index;
    logic cache_control;
    cache_op_t cache_control_op;
} decoded_instruction_t;

//
// Cache defines
//

parameter PAGE_SIZE = 'h1000;
parameter PAGE_NUM_BITS  = 32 - $clog2(PAGE_SIZE);
parameter ASID_WIDTH = 8;
parameter CACHE_LINE_BYTES = NUM_VECTOR_LANES * 4; // Must be same as vector width
parameter CACHE_LINE_BITS = CACHE_LINE_BYTES * 8;
parameter CACHE_LINE_WORDS = CACHE_LINE_BYTES / 4;
parameter CACHE_LINE_OFFSET_WIDTH = $clog2(CACHE_LINE_BYTES);    // Byte offset into a cache line
parameter ICACHE_TAG_BITS = 32 - (CACHE_LINE_OFFSET_WIDTH + $clog2(`L1I_SETS));
parameter DCACHE_TAG_BITS = 32 - (CACHE_LINE_OFFSET_WIDTH + $clog2(`L1D_SETS));

typedef logic[CACHE_LINE_BITS - 1:0] cache_line_data_t;
typedef logic[PAGE_NUM_BITS - 1:0] page_index_t;

typedef struct packed {
    logic[PAGE_NUM_BITS - 1:0] ppage_idx;
    logic[32 - (PAGE_NUM_BITS + 5) - 1:0] unused;
    logic global_map;
    logic supervisor;
    logic executable;
    logic writable;
    logic present;
} tlb_entry_t;

typedef logic[$clog2(`L1D_WAYS) - 1:0] l1d_way_idx_t;
typedef logic[$clog2(`L1D_SETS) - 1:0] l1d_set_idx_t;
typedef logic[DCACHE_TAG_BITS - 1:0] l1d_tag_t;

typedef struct packed {
    l1d_tag_t tag;
    l1d_set_idx_t set_idx;
    logic[CACHE_LINE_OFFSET_WIDTH - 1:0] offset;
} l1d_addr_t;

typedef logic[$clog2(`L1I_WAYS) - 1:0] l1i_way_idx_t;
typedef logic[$clog2(`L1I_SETS) - 1:0] l1i_set_idx_t;
typedef logic[ICACHE_TAG_BITS - 1:0] l1i_tag_t;

typedef struct packed {
    l1i_tag_t tag;
    l1i_set_idx_t set_idx;
    logic[CACHE_LINE_OFFSET_WIDTH - 1:0] offset;
} l1i_addr_t;

typedef logic[$clog2(`L2_WAYS) - 1:0] l2_way_idx_t;
typedef logic[$clog2(`L2_SETS) - 1:0] l2_set_idx_t;
typedef logic[(31 - (CACHE_LINE_OFFSET_WIDTH + $clog2(`L2_SETS))):0] l2_tag_t;
typedef struct packed {
    l2_tag_t tag;
    l2_set_idx_t set_idx;
} l2_addr_t;

// Memory address expressed as multiple of cache line size
typedef logic[31 - CACHE_LINE_OFFSET_WIDTH:0] cache_line_index_t;

typedef enum logic {
    CT_ICACHE,
    CT_DCACHE
} cache_type_t;

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

// L2 request
typedef struct packed {
    core_id_t core;
    l1_miss_entry_idx_t id;
    l2req_packet_type_t packet_type;
    cache_type_t cache_type;
    l2_addr_t address;
    logic[CACHE_LINE_BYTES - 1:0] store_mask;
    cache_line_data_t data;
} l2req_packet_t;

typedef enum logic[2:0] {
    L2RSP_LOAD_ACK,
    L2RSP_STORE_ACK,
    L2RSP_FLUSH_ACK,
    L2RSP_IINVALIDATE_ACK,
    L2RSP_DINVALIDATE_ACK
} l2rsp_packet_type_t;

// L2 response
typedef struct packed {
    logic status;
    core_id_t core;
    l1_miss_entry_idx_t id;
    l2rsp_packet_type_t packet_type;
    cache_type_t cache_type;
    l2_addr_t address;
    cache_line_data_t data;
} l2rsp_packet_t;

// I/O bus request
typedef struct packed {
    logic store;
    local_thread_idx_t thread_idx;
    scalar_t address;
    scalar_t value;
} ioreq_packet_t;

// I/O bus response
typedef struct packed {
    core_id_t core;
    local_thread_idx_t thread_idx;
    scalar_t read_value;
} iorsp_packet_t;

parameter AXI_ADDR_WIDTH = 32;

endpackage : defines

// Non-cached I/O bus (peripheral register access) external interface
// write_en and read_en are mutually exclusive. When read_en is asserted, the
// data will appear on read_data one cycle later.
interface io_bus_interface;
    logic write_en;
    logic read_en;
    defines::scalar_t address;
    defines::scalar_t write_data;
    defines::scalar_t read_data;

    modport master(output write_en, read_en, address, write_data, input read_data);
    modport slave(input write_en, read_en, address, write_data, output read_data);
endinterface

// AMBA AXI-4 bus interface
// See table A10-1 and A10-3 for default values of optional signals not included here.
interface axi4_interface;
    // Global signals (Table A2-1)
    logic m_aclk;
    logic m_aresetn;

    // Write address channel (Table A2-2)
    logic [AXI_ADDR_WIDTH - 1:0] m_awaddr;
    logic [7:0] m_awlen;
    logic [2:0] m_awprot;
    logic m_awvalid;
    logic s_awready;

    // Write data channel (Table A2-3)
    logic [`AXI_DATA_WIDTH - 1:0] m_wdata;
    logic m_wlast;
    logic m_wvalid;
    logic s_wready;

    // Write response channel (Table A2-4)
    logic s_bvalid;
    logic m_bready;

    // Read address channel (Table A2-5)
    logic [AXI_ADDR_WIDTH - 1:0] m_araddr;
    logic [7:0] m_arlen;
    logic [2:0] m_arprot;
    logic m_arvalid;
    logic s_arready;

    // Read data channel (Table A2-6)
    logic [`AXI_DATA_WIDTH - 1:0] s_rdata;
    logic s_rvalid;
    logic m_rready;

    modport master(input s_awready, s_wready, s_bvalid, s_arready, s_rvalid, s_rdata,
        output m_awaddr, m_awlen, m_awvalid, m_wdata, m_wlast, m_wvalid, m_bready, m_araddr,
        m_arlen, m_arvalid, m_rready, m_aclk, m_aresetn, m_arprot, m_awprot);
    modport slave(input m_awaddr, m_awlen, m_awvalid, m_wdata, m_wlast, m_wvalid, m_bready,
        m_araddr, m_arlen, m_arvalid, m_rready, m_aclk, m_aresetn, m_arprot, m_awprot,
        output s_awready, s_wready, s_bvalid, s_arready, s_rvalid, s_rdata);
endinterface

interface jtag_interface;
    logic tck;
    logic trst_n;
    logic tdi;
    logic tdo;
    logic tms;

    modport host(input tdi, output tck, trst_n, tdo, tms);
    modport target(input tck, trst_n, tdi, tms, output tdo);
endinterface

`endif
