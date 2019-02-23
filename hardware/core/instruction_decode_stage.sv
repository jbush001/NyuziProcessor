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

`include "defines.svh"

import defines::*;

//
// Instruction Pipeline - Instruction Decode Stage
// Populate the decoded_instruction_t structure with fields from
// the instruction. The structure contains control fields will be
// used later in the pipeline.
//
// This also handles interrupts. When an interrupt is pending, an existing
// instruction is replaced with one that has the trap flag set. This works
// similar to the way traps from earlier stages in the pipeline are handled
// and is necessary to make sure interrupts are precise (from the software
// perspective, the interrupt appears  to occur on a boundary between two
// instructions, with every prior instruction executing, and every subsequent
// instruction not). We must do it this way because:
// - Instructions can retire out of order
// - There may be pending instructions in the pipeline for the thread that
//   will cause a rollback in a subsequent cycle.
//
// Register port to operand mapping
//                                               store
//       format           op1     op2    mask    value
// +-------------------+-------+-------+-------+-------+
// | R - scalar/scalar |   s1  |   s2  |       |       |
// | R - vector/scalar |   v1  |   s2  |  s1   |       |
// | R - vector/vector |   v1  |   v2  |  s2   |       |
// | I - scalar        |   s1  |  imm  |  n/a  |       |
// | I - vector        |   v1  |  imm  |  s2   |       |
// | M - scalar        |   s1  |  imm  |  n/a  |  s2   |
// | M - block         |   s1  |  imm  |  s2   |  v2   |
// | M - scatter/gather|   v1  |  imm  |  s2   |  v2   |
// | C                 |   s1  |  imm  |       |       |
// | B                 |   s1  |       |       |       |
// +-------------------+-------+-------+-------+-------+
//

module instruction_decode_stage(
    input                         clk,
    input                         reset,

    // From ifetch_data_stage
    input                         ifd_instruction_valid,
    input scalar_t                ifd_instruction,
    input                         ifd_inst_injected,
    input scalar_t                ifd_pc,
    input local_thread_idx_t      ifd_thread_idx,
    input                         ifd_alignment_fault,
    input                         ifd_supervisor_fault,
    input                         ifd_page_fault,
    input                         ifd_executable_fault,
    input                         ifd_tlb_miss,

    // From dcache_data_stage
    input local_thread_bitmap_t   dd_load_sync_pending,

    // From l1_l2_interface
    input local_thread_bitmap_t   sq_store_sync_pending,

    // To thread_select_stage
    output decoded_instruction_t  id_instruction,
    output logic                  id_instruction_valid,
    output local_thread_idx_t     id_thread_idx,

    // From io_request_queue
    input local_thread_bitmap_t   ior_pending,

    // From control_registers
    input local_thread_bitmap_t   cr_interrupt_en,
    input local_thread_bitmap_t   cr_interrupt_pending,

    // From on_chip_debugger
    input                         ocd_halt,

    // From writeback_stage
    input                         wb_rollback_en,
    input local_thread_idx_t      wb_rollback_thread_idx);

    localparam T = 1'b1;
    localparam F = 1'b0;

    typedef enum logic[2:0] {
        IMM_ZERO,
        IMM_23_15,  // Masked immediate arithmetic
        IMM_23_10,  // Unmasked immediate arithmetic
        IMM_24_15,  // Masked memory access
        IMM_24_10,  // Unmasked memory access
        IMM_24_5,   // Small branch offset (multiply by four)
        IMM_24_0,   // Large branch offset (multiply by four)
        IMM_EXT_19  // 19 bit extended immediate value
    } imm_loc_t;

    typedef enum logic[1:0] {
        SCLR1_NONE,
        SCLR1_14_10,
        SCLR1_4_0
    } scalar1_loc_t;

    typedef enum logic[2:0] {
        SCLR2_NONE,
        SCLR2_19_15,
        SCLR2_14_10,
        SCLR2_9_5
    } scalar2_loc_t;

    struct packed {
        logic illegal;
        logic dest_vector;
        logic has_dest;
        imm_loc_t imm_loc;
        scalar1_loc_t scalar1_loc;
        scalar2_loc_t scalar2_loc;
        logic has_vector1;
        logic has_vector2;
        logic vector_sel2_9_5;    // Else is src2. Only for stores.
        logic op1_vector;
        op2_src_t op2_src;
        mask_src_t mask_src;
        logic store_value_vector;
        logic call;
    } dlut_out;

    decoded_instruction_t decoded_instr_nxt;
    logic nop;
    logic fmt_r;
    logic fmt_i;
    logic fmt_m;
    logic getlane;
    logic compare;
    alu_op_t alu_op;
    memory_op_t memory_access_type;
    register_idx_t scalar_sel2;
    logic has_trap;
    logic syscall;
    logic breakpoint;
    logic raise_interrupt;
    local_thread_bitmap_t masked_interrupt_flags;
    logic unary_arith;

    // I originally tried to structure the instruction set so that this could
    // determine the format of the instruction from the first 7 bits. Those
    // index into this ROM table that returns the decoded information. This
    // has become less true as the instruction set has evolved. Also, synthesis
    // tools just turn this into random logic. Should revisit this at some point.
    always_comb
    begin
        unique casez (ifd_instruction[31:25])
            // Format R (register arithmetic)
            7'b110_000_?: dlut_out = {F, F, T, IMM_ZERO, SCLR1_4_0, SCLR2_19_15,   F, F, F, F, OP2_SRC_SCALAR2, MASK_SRC_ALL_ONES, F, F};
            7'b110_001_?: dlut_out = {F, T, T, IMM_ZERO, SCLR1_4_0, SCLR2_19_15,   T, F, F, T, OP2_SRC_SCALAR2, MASK_SRC_ALL_ONES, F, F};
            7'b110_010_?: dlut_out = {F, T, T, IMM_ZERO, SCLR1_14_10, SCLR2_19_15, T, F, F, T, OP2_SRC_SCALAR2, MASK_SRC_SCALAR1, F, F};
            7'b110_100_?: dlut_out = {F, T, T, IMM_ZERO, SCLR1_14_10, SCLR2_NONE,  T, T, F, T, OP2_SRC_VECTOR2, MASK_SRC_ALL_ONES, F, F};
            7'b110_101_?: dlut_out = {F, T, T, IMM_ZERO, SCLR1_4_0, SCLR2_14_10,   T, T, F, T, OP2_SRC_VECTOR2, MASK_SRC_SCALAR2, F, F};

            // Format I (immediate arithmetic)
            7'b0_00_????: dlut_out = {F, F, T, IMM_23_10, SCLR1_4_0, SCLR2_NONE,   F, F, F, F, OP2_SRC_IMMEDIATE, MASK_SRC_ALL_ONES, F, F};
            7'b0_01_????: dlut_out = {F, T, T, IMM_23_10, SCLR1_4_0, SCLR2_NONE,   T, F, F, T, OP2_SRC_IMMEDIATE, MASK_SRC_ALL_ONES, F, F};
            7'b0_10_????: dlut_out = {F, F, T, IMM_EXT_19, SCLR1_4_0, SCLR2_NONE,  F, F, F, F, OP2_SRC_IMMEDIATE, MASK_SRC_ALL_ONES, F, F};
            7'b0_11_????: dlut_out = {F, T, T, IMM_23_15, SCLR1_4_0, SCLR2_14_10,  T, F, F, T, OP2_SRC_IMMEDIATE, MASK_SRC_SCALAR2, F, F};

            // Format M (memory)
            // Store
            7'b10_0_0000: dlut_out = {F, F, F, IMM_24_10, SCLR1_4_0, SCLR2_9_5,     F, F, T, F, OP2_SRC_IMMEDIATE, MASK_SRC_ALL_ONES, F, F};
            7'b10_0_0001: dlut_out = {F, F, F, IMM_24_10, SCLR1_4_0, SCLR2_9_5,     F, F, T, F, OP2_SRC_IMMEDIATE, MASK_SRC_ALL_ONES, F, F};
            7'b10_0_0010: dlut_out = {F, F, F, IMM_24_10, SCLR1_4_0, SCLR2_9_5,     T, F, T, F, OP2_SRC_IMMEDIATE, MASK_SRC_ALL_ONES, F, F};
            7'b10_0_0011: dlut_out = {F, F, F, IMM_24_10, SCLR1_4_0, SCLR2_9_5,     F, F, T, F, OP2_SRC_IMMEDIATE, MASK_SRC_ALL_ONES, F, F};
            7'b10_0_0100: dlut_out = {F, F, F, IMM_24_10, SCLR1_4_0, SCLR2_9_5,     F, F, T, F, OP2_SRC_IMMEDIATE, MASK_SRC_ALL_ONES, F, F};
            7'b10_0_0101: dlut_out = {F, F, T, IMM_24_10, SCLR1_4_0, SCLR2_9_5,     F, F, T, F, OP2_SRC_IMMEDIATE, MASK_SRC_ALL_ONES, F, F};
            7'b10_0_0110: dlut_out = {F, F, F, IMM_24_10, SCLR1_4_0, SCLR2_9_5,     F, F, T, F, OP2_SRC_IMMEDIATE, MASK_SRC_ALL_ONES, F, F};
            7'b10_0_0111: dlut_out = {F, F, F, IMM_24_10, SCLR1_4_0, SCLR2_NONE,    F, T, T, F, OP2_SRC_IMMEDIATE, MASK_SRC_ALL_ONES, T, F};
            7'b10_0_1000: dlut_out = {F, F, F, IMM_24_15, SCLR1_4_0, SCLR2_14_10, F, T, T, F, OP2_SRC_IMMEDIATE, MASK_SRC_SCALAR2, T, F};
            7'b10_0_1101: dlut_out = {F, F, F, IMM_24_10, SCLR1_4_0, SCLR2_NONE,    T, T, T, T, OP2_SRC_IMMEDIATE, MASK_SRC_ALL_ONES, T, F};
            7'b10_0_1110: dlut_out = {F, F, F, IMM_24_15, SCLR1_4_0, SCLR2_14_10, T, T, T, T, OP2_SRC_IMMEDIATE, MASK_SRC_SCALAR2, T, F};

            // Load
            7'b10_1_0000: dlut_out = {F, F, T, IMM_24_10, SCLR1_4_0, SCLR2_NONE,    T, F, F, F, OP2_SRC_IMMEDIATE, MASK_SRC_ALL_ONES, F, F};
            7'b10_1_0001: dlut_out = {F, F, T, IMM_24_10, SCLR1_4_0, SCLR2_NONE,    T, F, F, F, OP2_SRC_IMMEDIATE, MASK_SRC_ALL_ONES, F, F};
            7'b10_1_0010: dlut_out = {F, F, T, IMM_24_10, SCLR1_4_0, SCLR2_NONE,    T, F, F, F, OP2_SRC_IMMEDIATE, MASK_SRC_ALL_ONES, F, F};
            7'b10_1_0011: dlut_out = {F, F, T, IMM_24_10, SCLR1_4_0, SCLR2_NONE,    T, F, F, F, OP2_SRC_IMMEDIATE, MASK_SRC_ALL_ONES, F, F};
            7'b10_1_0100: dlut_out = {F, F, T, IMM_24_10, SCLR1_4_0, SCLR2_NONE,    T, F, F, F, OP2_SRC_IMMEDIATE, MASK_SRC_ALL_ONES, F, F};
            7'b10_1_0101: dlut_out = {F, F, T, IMM_24_10, SCLR1_4_0, SCLR2_NONE,    T, F, F, F, OP2_SRC_IMMEDIATE, MASK_SRC_ALL_ONES, F, F};
            7'b10_1_0110: dlut_out = {F, F, T, IMM_24_10, SCLR1_4_0, SCLR2_NONE,    T, F, F, F, OP2_SRC_IMMEDIATE, MASK_SRC_ALL_ONES, F, F};
            7'b10_1_0111: dlut_out = {F, T, T, IMM_24_10, SCLR1_4_0, SCLR2_NONE,    T, F, F, F, OP2_SRC_IMMEDIATE, MASK_SRC_ALL_ONES, F, F};
            7'b10_1_1000: dlut_out = {F, T, T, IMM_24_15, SCLR1_4_0, SCLR2_14_10, T, F, F, F, OP2_SRC_IMMEDIATE, MASK_SRC_SCALAR2, F, F};
            7'b10_1_1101: dlut_out = {F, T, T, IMM_24_10, SCLR1_4_0, SCLR2_NONE,    T, T, F, T, OP2_SRC_IMMEDIATE, MASK_SRC_ALL_ONES, F, F};
            7'b10_1_1110: dlut_out = {F, T, T, IMM_24_15, SCLR1_4_0, SCLR2_14_10, T, T, F, T, OP2_SRC_IMMEDIATE, MASK_SRC_SCALAR2, F, F};

            // Format C (cache control)
            7'b1110_000: dlut_out = {F, F, F,  IMM_24_15, SCLR1_4_0, SCLR2_9_5,  F, F, F, F, OP2_SRC_IMMEDIATE, MASK_SRC_ALL_ONES, F, F};
            7'b1110_001: dlut_out = {F, F, F,  IMM_24_15, SCLR1_4_0, SCLR2_NONE,  F, F, F, F, OP2_SRC_IMMEDIATE, MASK_SRC_ALL_ONES, F, F};
            7'b1110_010: dlut_out = {F, F, F,  IMM_24_15, SCLR1_4_0, SCLR2_NONE,  F, F, F, F, OP2_SRC_IMMEDIATE, MASK_SRC_ALL_ONES, F, F};
            7'b1110_011: dlut_out = {F, F, F,  IMM_24_15, SCLR1_4_0, SCLR2_NONE,  F, F, F, F, OP2_SRC_IMMEDIATE, MASK_SRC_ALL_ONES, F, F};
            7'b1110_100: dlut_out = {F, F, F,  IMM_24_15, SCLR1_NONE, SCLR2_NONE, F, F, F, F, OP2_SRC_IMMEDIATE, MASK_SRC_ALL_ONES, F, F};
            7'b1110_101: dlut_out = {F, F, F,  IMM_24_15, SCLR1_4_0, SCLR2_NONE,  F, F, F, F, OP2_SRC_IMMEDIATE, MASK_SRC_ALL_ONES, F, F};
            7'b1110_110: dlut_out = {F, F, F,  IMM_24_15, SCLR1_NONE, SCLR2_NONE, F, F, F, F, OP2_SRC_IMMEDIATE, MASK_SRC_ALL_ONES, F, F};
            7'b1110_111: dlut_out = {F, F, F,  IMM_24_15, SCLR1_4_0, SCLR2_9_5,  F, F, F, F, OP2_SRC_IMMEDIATE, MASK_SRC_ALL_ONES, F, F};

            // Format B (branch)
            7'b1111_000: dlut_out = {F, F, F, IMM_24_5, SCLR1_4_0, SCLR2_NONE,   F, F, F, F, OP2_SRC_IMMEDIATE, MASK_SRC_ALL_ONES, F, F};
            7'b1111_001: dlut_out = {F, F, F, IMM_24_5, SCLR1_4_0, SCLR2_NONE,   F, F, F, F, OP2_SRC_IMMEDIATE, MASK_SRC_ALL_ONES, F, F};
            7'b1111_010: dlut_out = {F, F, F, IMM_24_5, SCLR1_4_0, SCLR2_NONE,   F, F, F, F, OP2_SRC_IMMEDIATE, MASK_SRC_ALL_ONES, F, F};
            7'b1111_011: dlut_out = {F, F, F, IMM_24_0, SCLR1_NONE, SCLR2_NONE,  F, F, F, F, OP2_SRC_IMMEDIATE, MASK_SRC_ALL_ONES, F, F};
            7'b1111_100: dlut_out = {F, F, T, IMM_24_0, SCLR1_NONE, SCLR2_NONE,  F, F, F, F, OP2_SRC_SCALAR2, MASK_SRC_ALL_ONES, F, T};
            7'b1111_110: dlut_out = {F, F, T, IMM_24_5, SCLR1_4_0, SCLR2_NONE,   F, F, F, F, OP2_SRC_SCALAR2, MASK_SRC_ALL_ONES, F, T};
            7'b1111_111: dlut_out = {F, F, T, IMM_24_5, SCLR1_4_0, SCLR2_NONE,   F, F, F, F, OP2_SRC_SCALAR2, MASK_SRC_ALL_ONES, F, F};

            // Invalid instruction format
            default: dlut_out = {T, F, F, IMM_ZERO, SCLR1_NONE, SCLR2_NONE, F, F, F, F, OP2_SRC_IMMEDIATE, MASK_SRC_ALL_ONES, F, F};
        endcase
    end

    assign fmt_r = ifd_instruction[31:29] == 3'b110;    // register arithmetic
    assign fmt_i = ifd_instruction[31] == 1'b0;    // immediate arithmetic
    assign fmt_m = ifd_instruction[31:30] == 2'b10;
    assign getlane = (fmt_r || fmt_i) && alu_op == OP_GETLANE;

    assign syscall = fmt_i && 6'(ifd_instruction[28:24]) == OP_SYSCALL;
    assign breakpoint = fmt_r && ifd_instruction[25:20] == OP_BREAKPOINT;
    assign nop = ifd_instruction == INSTRUCTION_NOP;
    assign has_trap = (ifd_instruction_valid
        && (dlut_out.illegal || syscall || breakpoint || raise_interrupt))
        || ifd_alignment_fault || ifd_tlb_miss
        || ifd_supervisor_fault
        || ifd_page_fault || ifd_executable_fault;

    // Check for TLB miss first, since permission bits are not valid if there
    // is a TLB miss. The order of the remaining faults should match that in
    // dcache_data_stage for consistency.
    always_comb
    begin
        if (raise_interrupt)
            decoded_instr_nxt.trap_cause = {2'b00, TT_INTERRUPT};
        else if (ifd_tlb_miss)
            decoded_instr_nxt.trap_cause = {2'b00, TT_TLB_MISS};
        else if (ifd_page_fault)
            decoded_instr_nxt.trap_cause = {2'b00, TT_PAGE_FAULT};
        else if (ifd_supervisor_fault)
            decoded_instr_nxt.trap_cause = {2'b00, TT_SUPERVISOR_ACCESS};
        else if (ifd_alignment_fault)
            decoded_instr_nxt.trap_cause = {2'b00, TT_UNALIGNED_ACCESS};
        else if (ifd_executable_fault)
            decoded_instr_nxt.trap_cause = {2'b00, TT_NOT_EXECUTABLE};
        else if (dlut_out.illegal)
            decoded_instr_nxt.trap_cause = {2'b00, TT_ILLEGAL_INSTRUCTION};
        else if (syscall)
            decoded_instr_nxt.trap_cause = {2'b00, TT_SYSCALL};
        else if (breakpoint)
            decoded_instr_nxt.trap_cause = {2'b00, TT_BREAKPOINT};
        else
            decoded_instr_nxt.trap_cause = {2'b00, TT_RESET};
    end

    assign decoded_instr_nxt.injected = ifd_inst_injected;

    // Subtle: Certain instructions need to be issued twice, including I/O
    // requests and synchronized memory accesses. The first queues the
    // transaction and the second collects the result. Because the first
    // instruction updates internal state, bad things would happen if an
    // interrupt were dispatched between them. To avoid this, don't dispatch
    // an interrupt if the first instruction has been issued (indicated by
    // dd_load_sync_pending, ior_pending, or sq_store_sync_pending).
    assign masked_interrupt_flags = cr_interrupt_pending & cr_interrupt_en
        & ~ior_pending & ~dd_load_sync_pending & ~sq_store_sync_pending;
    assign raise_interrupt = masked_interrupt_flags[ifd_thread_idx] && !ocd_halt;
    assign decoded_instr_nxt.has_trap = has_trap;

    assign unary_arith = fmt_r && (alu_op == OP_CLZ
        || alu_op == OP_CTZ
        || alu_op == OP_MOVE
        || alu_op == OP_FTOI
        || alu_op == OP_RECIPROCAL
        || alu_op == OP_SEXT8
        || alu_op == OP_SEXT16
        || alu_op == OP_ITOF)
        && dlut_out.mask_src != MASK_SRC_SCALAR1;
    assign decoded_instr_nxt.has_scalar1 = dlut_out.scalar1_loc != SCLR1_NONE && !nop
        && !has_trap && !unary_arith;
    always_comb
    begin
        unique case (dlut_out.scalar1_loc)
            SCLR1_14_10: decoded_instr_nxt.scalar_sel1 = ifd_instruction[14:10];
            default: decoded_instr_nxt.scalar_sel1 = ifd_instruction[4:0]; //  src1
        endcase
    end

    assign decoded_instr_nxt.has_scalar2 = dlut_out.scalar2_loc != SCLR2_NONE && !nop
        && !has_trap;

    // XXX: assigning this directly to decoded_instr_nxt.scalar_sel2 causes Verilator issues when
    // other blocks read it. Added another signal to work around this.
    always_comb
    begin
        unique case (dlut_out.scalar2_loc)
            SCLR2_14_10: scalar_sel2 = ifd_instruction[14:10];
            SCLR2_19_15: scalar_sel2 = ifd_instruction[19:15];
            SCLR2_9_5: scalar_sel2 = ifd_instruction[9:5];
            default: scalar_sel2 = 0;
        endcase
    end

    assign decoded_instr_nxt.scalar_sel2 = scalar_sel2;
    assign decoded_instr_nxt.has_vector1 = dlut_out.has_vector1 && !nop && !has_trap;
    assign decoded_instr_nxt.vector_sel1 = ifd_instruction[4:0];
    assign decoded_instr_nxt.has_vector2 = dlut_out.has_vector2 && !nop && !has_trap;
    always_comb
    begin
        if (dlut_out.vector_sel2_9_5)
            decoded_instr_nxt.vector_sel2 = ifd_instruction[9:5];
        else
            decoded_instr_nxt.vector_sel2 = ifd_instruction[19:15];
    end

    assign decoded_instr_nxt.has_dest = dlut_out.has_dest && !nop && !has_trap;

    assign decoded_instr_nxt.dest_vector = dlut_out.dest_vector && !compare
        && !getlane;
    assign decoded_instr_nxt.dest_reg = dlut_out.call ? REG_RA : ifd_instruction[9:5];
    assign decoded_instr_nxt.call = dlut_out.call;
    always_comb
    begin
        if (fmt_i)
            alu_op = alu_op_t'({1'b0, ifd_instruction[28:24]});
        else if (dlut_out.call)
            alu_op = OP_MOVE;    // Treat a call as move ra, pc
        else
            alu_op = alu_op_t'(ifd_instruction[25:20]); // Format R
    end

    assign decoded_instr_nxt.alu_op = alu_op;
    assign decoded_instr_nxt.mask_src = dlut_out.mask_src;
    assign decoded_instr_nxt.store_value_vector = dlut_out.store_value_vector;

    // Decode operand source ports, checking specifically for PC operands
    always_comb
    begin
        if (dlut_out.op1_vector)
            decoded_instr_nxt.op1_src = OP1_SRC_VECTOR1;
        else
            decoded_instr_nxt.op1_src = OP1_SRC_SCALAR1;
    end

    assign decoded_instr_nxt.op2_src = dlut_out.op2_src;

    always_comb
    begin
        unique case (dlut_out.imm_loc)
            IMM_EXT_19: decoded_instr_nxt.immediate_value = { ifd_instruction[23:10], ifd_instruction[4:0], 13'd0 };
            IMM_23_15: decoded_instr_nxt.immediate_value = scalar_t'($signed(ifd_instruction[23:15]));
            IMM_23_10: decoded_instr_nxt.immediate_value = scalar_t'($signed(ifd_instruction[23:10]));
            IMM_24_15: decoded_instr_nxt.immediate_value = scalar_t'($signed(ifd_instruction[24:15]));
            IMM_24_10: decoded_instr_nxt.immediate_value = scalar_t'($signed(ifd_instruction[24:10]));

            // Branch offsets are multiplied by four
            IMM_24_5: decoded_instr_nxt.immediate_value = scalar_t'($signed({ifd_instruction[24:5], 2'b00}));
            IMM_24_0: decoded_instr_nxt.immediate_value = scalar_t'($signed({ifd_instruction[24:0], 2'b00}));
            default: decoded_instr_nxt.immediate_value = 0;
        endcase
    end

    assign decoded_instr_nxt.branch_type = branch_type_t'(ifd_instruction[27:25]);
    assign decoded_instr_nxt.branch = ifd_instruction[31:28] == 4'b1111
        && !has_trap;
    assign decoded_instr_nxt.pc = ifd_pc;

    always_comb
    begin
        if (has_trap)
            decoded_instr_nxt.pipeline_sel = PIPE_INT_ARITH;
        else if (fmt_r || fmt_i)
        begin
            if (alu_op[5] || alu_op == OP_MULL_I || alu_op == OP_MULH_U
                 || alu_op == OP_MULH_I || alu_op == OP_FTOI)
                decoded_instr_nxt.pipeline_sel = PIPE_FLOAT_ARITH;
            else
                decoded_instr_nxt.pipeline_sel = PIPE_INT_ARITH;
        end
        else if (ifd_instruction[31:28] == 4'b1111)
            decoded_instr_nxt.pipeline_sel = PIPE_INT_ARITH; // branches evaluated in integer pipeline
        else
            decoded_instr_nxt.pipeline_sel = PIPE_MEM;
    end

    assign memory_access_type = memory_op_t'(ifd_instruction[28:25]);
    assign decoded_instr_nxt.memory_access_type = memory_access_type;
    assign decoded_instr_nxt.memory_access = ifd_instruction[31:30] == 2'b10
        && !has_trap;
    assign decoded_instr_nxt.load = ifd_instruction[29]
        && fmt_m;
    assign decoded_instr_nxt.cache_control = ifd_instruction[31:28] == 4'b1110
         && !has_trap;
    assign decoded_instr_nxt.cache_control_op = cache_op_t'(ifd_instruction[27:25]);

    always_comb
    begin
        if (ifd_instruction[31:30] == 2'b10
            && (memory_access_type == MEM_SCGATH
            || memory_access_type == MEM_SCGATH_M))
        begin
            // Scatter/Gather access
            decoded_instr_nxt.last_subcycle = subcycle_t'(NUM_VECTOR_LANES - 1);
        end
        else
            decoded_instr_nxt.last_subcycle = 0;
    end

    assign decoded_instr_nxt.creg_index = control_register_t'(ifd_instruction[4:0]);

    assign compare = (fmt_r || fmt_i)
        && (alu_op == OP_CMPEQ_I
        || alu_op == OP_CMPNE_I
        || alu_op == OP_CMPGT_I
        || alu_op == OP_CMPGE_I
        || alu_op == OP_CMPLT_I
        || alu_op == OP_CMPLE_I
        || alu_op == OP_CMPGT_U
        || alu_op == OP_CMPGE_U
        || alu_op == OP_CMPLT_U
        || alu_op == OP_CMPLE_U
        || alu_op == OP_CMPGT_F
        || alu_op == OP_CMPLT_F
        || alu_op == OP_CMPGE_F
        || alu_op == OP_CMPLE_F
        || alu_op == OP_CMPEQ_F
        || alu_op == OP_CMPNE_F);
    assign decoded_instr_nxt.compare = compare;

    always_ff @(posedge clk)
    begin
        id_instruction <= decoded_instr_nxt;
        id_thread_idx <= ifd_thread_idx;
    end

    always_ff @(posedge clk, posedge reset)
    begin
        if (reset)
            id_instruction_valid <= '0;
        else
        begin
            // Piggyback ifetch faults and TLB misses inside instructions, marking
            // the instruction valid if these conditions occur
            id_instruction_valid <= (ifd_instruction_valid || has_trap)
                && (!wb_rollback_en || wb_rollback_thread_idx != ifd_thread_idx);
        end
    end
endmodule
