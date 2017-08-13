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

`include "defines.sv"

import defines::*;

//
// Instruction Pipeline Writeback Stage
// - Selects result from appropriate pipeline (memory, integer, floating point)
// - Aligns memory read results
// - Writes results back to register file
// - Handles rollbacks. Most are raised earlier in the pipeline, but it
//   handles them here to avoid having to reconcile multiple rollbacks in
//   the same cycle.
//   * Branch
//   * Data cache miss
//   * Exception
//
// Exceptions and interrupts are precise in this architecture. This is
// complicated by the fact that instructions may retire out of order because
// the execution pipelines have different lengths. It's also possible, after
// a rollback, for earlier instructions from the same thread to arrive at
// this stage (because they were in the longer floating point pipeline).
// The rollback signal does not flush later stages of the multicycle pipeline
// for this reason.
//

module writeback_stage(
    input                                 clk,
    input                                 reset,

    // From fp_execute_stage5 (floating point pipline)
    input                                 fx5_instruction_valid,
    input decoded_instruction_t           fx5_instruction,
    input vector_t                        fx5_result,
    input vector_lane_mask_t              fx5_mask_value,
    input local_thread_idx_t              fx5_thread_idx,
    input subcycle_t                      fx5_subcycle,

    // From int_execute_stage (integer pipeline)
    input                                 ix_instruction_valid,
    input decoded_instruction_t           ix_instruction,
    input vector_t                        ix_result,
    input local_thread_idx_t              ix_thread_idx,
    input vector_lane_mask_t              ix_mask_value,
    input logic                           ix_rollback_en,
    input scalar_t                        ix_rollback_pc,
    input subcycle_t                      ix_subcycle,
    input                                 ix_privileged_op_fault,

    // From dcache_data_stage (memory pipeline)
    input                                 dd_instruction_valid,
    input decoded_instruction_t           dd_instruction,
    input vector_lane_mask_t              dd_lane_mask,
    input local_thread_idx_t              dd_thread_idx,
    input l1d_addr_t                      dd_request_vaddr,
    input subcycle_t                      dd_subcycle,
    input                                 dd_rollback_en,
    input scalar_t                        dd_rollback_pc,
    input cache_line_data_t               dd_load_data,
    input                                 dd_suspend_thread,
    input                                 dd_is_io_address,
    input logic                           dd_fault,
    input trap_cause_t                    dd_fault_cause,

    // From l1_store_queue
    input [CACHE_LINE_BYTES - 1:0]        sq_store_bypass_mask,
    input cache_line_data_t               sq_store_bypass_data,
    input                                 sq_store_sync_success,
    input                                 sq_rollback_en,

    // From io_request_queue
    input scalar_t                        ior_read_value,
    input logic                           ior_rollback_en,

    // From control_registers
    input scalar_t                        cr_creg_read_val,
    input scalar_t                        cr_trap_handler,
    input scalar_t                        cr_tlb_miss_handler,
    input subcycle_t                      cr_eret_subcycle[`THREADS_PER_CORE],

    // To control_registers
    output logic                          wb_trap,
    output trap_cause_t                   wb_trap_cause,
    output scalar_t                       wb_trap_pc,
    output local_thread_idx_t             wb_trap_thread_idx,
    output scalar_t                       wb_trap_access_vaddr,
    output subcycle_t                     wb_trap_subcycle,

    // Rollback signals to all stages
    output logic                          wb_rollback_en,
    output local_thread_idx_t             wb_rollback_thread_idx,
    output scalar_t                       wb_rollback_pc,
    output pipeline_sel_t                 wb_rollback_pipeline,
    output subcycle_t                     wb_rollback_subcycle,

    // To operand_fetch_stage/thread_select_stage
    output logic                          wb_writeback_en,
    output local_thread_idx_t             wb_writeback_thread_idx,
    output logic                          wb_writeback_is_vector,
    output vector_t                       wb_writeback_value,
    output vector_lane_mask_t             wb_writeback_mask,
    output register_idx_t                 wb_writeback_reg,
    output logic                          wb_writeback_is_last_subcycle,

    // To thread_select_stage
    output local_thread_bitmap_t          wb_suspend_thread_oh,

    // To performance_counters
    output logic                          wb_perf_instruction_retire,
    output logic                          wb_perf_store_rollback);

    scalar_t mem_load_lane;
    logic[$clog2(CACHE_LINE_WORDS) - 1:0] mem_load_lane_idx;
    logic[7:0] byte_aligned;
    logic[15:0] half_aligned;
    logic[31:0] swapped_word_value;
    memory_op_t memory_op;
    cache_line_data_t endian_twiddled_data;
`ifdef SIMULATION
    // Used by testbench
    scalar_t __debug_wb_pc;
    pipeline_sel_t __debug_wb_pipeline;
    logic __debug_is_sync_store;
`endif
    logic[NUM_VECTOR_LANES - 1:0] scycle_vcompare_result;
    logic[NUM_VECTOR_LANES - 1:0] mcycle_vcompare_result;
    vector_lane_mask_t dd_vector_lane_oh;
    cache_line_data_t bypassed_read_data;
    local_thread_bitmap_t thread_dd_oh;
    logic is_last_subcycle_dd;
    logic is_last_subcycle_sx;
    logic is_last_subcycle_mx;
    logic writeback_en_nxt;
    local_thread_idx_t writeback_thread_idx_nxt;
    logic writeback_is_vector_nxt;
    vector_t writeback_value_nxt;
    vector_lane_mask_t writeback_mask_nxt;
    register_idx_t writeback_reg_nxt;
    logic writeback_is_last_subcycle_nxt;

    assign wb_perf_instruction_retire = fx5_instruction_valid || ix_instruction_valid
        || dd_instruction_valid;
    assign wb_perf_store_rollback = sq_rollback_en;

    //
    // Rollback control logic
    //
    // These signals are not registered because the next instruction may be a
    // memory store and we must squash it before it applies its side effects.
    // This stage handles all rollbacks, so there can be only one asserted at a
    // time.
    //
    always_comb
    begin
        // XXX wb_trap_thread_idx seems to be the same as wb_rollback_thread_idx.
        // Should these be combined?

        wb_rollback_en = 0;
        wb_rollback_pc = 0;
        wb_rollback_thread_idx = 0;
        wb_rollback_pipeline = PIPE_INT_ARITH;
        wb_trap = 0;
        wb_trap_cause = {2'b0, TT_RESET};
        wb_rollback_subcycle = 0;
        wb_trap_pc = 0;
        wb_trap_access_vaddr = 0;
        wb_trap_thread_idx = 0;
        wb_trap_subcycle = dd_subcycle;

        if (ix_instruction_valid && (ix_instruction.has_trap
            || ix_privileged_op_fault))
        begin
            // Fault piggybacked on instruction, which goes through the
            // integer pipeline.
            wb_rollback_en = 1;
            if (ix_instruction.trap_cause.trap_type == TT_TLB_MISS)
                wb_rollback_pc = cr_tlb_miss_handler;
            else
                wb_rollback_pc = cr_trap_handler;

            wb_rollback_thread_idx = ix_thread_idx;
            wb_rollback_pipeline = PIPE_INT_ARITH;
            wb_trap = 1;
            if (ix_privileged_op_fault)
                wb_trap_cause = {2'b0, TT_PRIVILEGED_OP};
            else
                wb_trap_cause = ix_instruction.trap_cause;

            wb_trap_pc = ix_instruction.pc;
            wb_trap_access_vaddr = ix_instruction.pc;
            wb_trap_thread_idx = ix_thread_idx;
            wb_trap_subcycle = ix_subcycle;
        end
        else if (dd_instruction_valid && dd_fault)
        begin
            // Memory access fault
            wb_rollback_en = 1'b1;
            if (dd_fault_cause.trap_type == TT_TLB_MISS)
                wb_rollback_pc = cr_tlb_miss_handler;
            else
                wb_rollback_pc = cr_trap_handler;

            wb_rollback_thread_idx = dd_thread_idx;
            wb_rollback_pipeline = PIPE_MEM;
            wb_trap = 1;
            wb_trap_cause = dd_fault_cause;
            wb_trap_pc = dd_instruction.pc;
            wb_trap_access_vaddr = dd_request_vaddr;
            wb_trap_thread_idx = dd_thread_idx;
        end
        else if (ix_instruction_valid && ix_rollback_en)
        begin
            // Check for rollback from integer pipeline. This happens
            // because of a branch.
            wb_rollback_en = 1;
            wb_rollback_pc = ix_rollback_pc;
            wb_rollback_thread_idx = ix_thread_idx;
            wb_rollback_pipeline = PIPE_INT_ARITH;
            if (ix_instruction.branch_type == BRANCH_ERET)
                wb_rollback_subcycle = cr_eret_subcycle[ix_thread_idx];
            else
                wb_rollback_subcycle = ix_subcycle;
        end
        else if (dd_instruction_valid && (dd_rollback_en || sq_rollback_en || ior_rollback_en))
        begin
            // Check for rollback from memory pipeline. This happens because
            // of a data cache miss, store queue full, or when an IO request
            // is sent.
            wb_rollback_en = 1;
            wb_rollback_pc = dd_rollback_pc;
            wb_rollback_thread_idx = dd_thread_idx;
            wb_rollback_pipeline = PIPE_MEM;
            wb_rollback_subcycle = dd_subcycle;
        end
    end

    idx_to_oh #(
        .NUM_SIGNALS(`THREADS_PER_CORE),
        .DIRECTION("LSB0")
    ) idx_to_oh_thread(
        .one_hot(thread_dd_oh),
        .index(dd_thread_idx));

    // Suspend thread if necessary
    assign wb_suspend_thread_oh = (dd_suspend_thread || sq_rollback_en || ior_rollback_en)
        ? thread_dd_oh : local_thread_bitmap_t'(0);

    // If there is a pending store for the value that was just read, merge it into
    // the data returned from the L1 data cache.
    genvar byte_lane;
    generate
        for (byte_lane = 0; byte_lane < CACHE_LINE_BYTES; byte_lane++)
        begin : lane_bypass_gen
            assign bypassed_read_data[byte_lane * 8+:8] = sq_store_bypass_mask[byte_lane]
                ? sq_store_bypass_data[byte_lane * 8+:8] : dd_load_data[byte_lane * 8+:8];
        end
    endgenerate

    assign memory_op = dd_instruction.memory_access_type;
    assign mem_load_lane_idx = ~dd_request_vaddr.offset[2+:$clog2(CACHE_LINE_WORDS)];
    assign mem_load_lane = bypassed_read_data[mem_load_lane_idx * 32+:32];

    // Byte memory load aligner.
    always_comb
    begin
        case (dd_request_vaddr.offset[1:0])
            2'd0: byte_aligned = mem_load_lane[31:24];
            2'd1: byte_aligned = mem_load_lane[23:16];
            2'd2: byte_aligned = mem_load_lane[15:8];
            2'd3: byte_aligned = mem_load_lane[7:0];
            default: byte_aligned = '0;
        endcase
    end

    // Halfword memory load aligner.
    always_comb
    begin
        case (dd_request_vaddr.offset[1])
            1'd0: half_aligned = {mem_load_lane[23:16], mem_load_lane[31:24]};
            1'd1: half_aligned = {mem_load_lane[7:0], mem_load_lane[15:8]};
            default: half_aligned = '0;
        endcase
    end

    assign swapped_word_value = {
        mem_load_lane[7:0],
        mem_load_lane[15:8],
        mem_load_lane[23:16],
        mem_load_lane[31:24]
    };

    // Endian swap memory load
    genvar swap_word;
    generate
        for (swap_word = 0; swap_word < CACHE_LINE_BYTES / 4; swap_word++)
        begin : swap_word_gen
            assign endian_twiddled_data[swap_word * 32+:8] = bypassed_read_data[swap_word * 32 + 24+:8];
            assign endian_twiddled_data[swap_word * 32 + 8+:8] = bypassed_read_data[swap_word * 32 + 16+:8];
            assign endian_twiddled_data[swap_word * 32 + 16+:8] = bypassed_read_data[swap_word * 32 + 8+:8];
            assign endian_twiddled_data[swap_word * 32 + 24+:8] = bypassed_read_data[swap_word * 32+:8];
        end
    endgenerate

    // Compress vector comparisons to one bit per lane.
    genvar mask_lane;
    generate
        for (mask_lane = 0; mask_lane < NUM_VECTOR_LANES; mask_lane++)
        begin : compare_result_gen
            assign scycle_vcompare_result[mask_lane] = ix_result[NUM_VECTOR_LANES - mask_lane - 1][0];
            assign mcycle_vcompare_result[mask_lane] = fx5_result[NUM_VECTOR_LANES - mask_lane - 1][0];
        end
    endgenerate

    idx_to_oh #(
        .NUM_SIGNALS(NUM_VECTOR_LANES),
        .DIRECTION("LSB0")
    ) convert_dd_lane(
        .one_hot(dd_vector_lane_oh),
        .index(dd_subcycle));

    assign is_last_subcycle_dd = dd_subcycle == dd_instruction.last_subcycle;
    assign is_last_subcycle_sx = ix_subcycle == ix_instruction.last_subcycle;
    assign is_last_subcycle_mx = fx5_subcycle == fx5_instruction.last_subcycle;

    always_comb
    begin
        writeback_en_nxt = 0;
        writeback_thread_idx_nxt = 0;
        writeback_mask_nxt = 0;
        writeback_value_nxt = 0;
        writeback_is_vector_nxt = 0;
        writeback_reg_nxt = 0;
        writeback_is_last_subcycle_nxt = 0;

        // wb_rollback_en is derived combinatorially from the instruction
        // that is about to retire, so this doesn't need to check
        // wb_rollback_thread_idx like other places.
        case ({fx5_instruction_valid, ix_instruction_valid, dd_instruction_valid})
            //
            // Floating point pipeline result
            //
            3'b100:
            begin
                if (fx5_instruction.has_dest && !wb_rollback_en)
                    writeback_en_nxt = 1;

                writeback_thread_idx_nxt = fx5_thread_idx;
                writeback_mask_nxt = fx5_mask_value;
                if (fx5_instruction.is_compare)
                    writeback_value_nxt = vector_t'(mcycle_vcompare_result);
                else
                    writeback_value_nxt = fx5_result;

                writeback_is_vector_nxt = fx5_instruction.dest_is_vector;
                writeback_reg_nxt = fx5_instruction.dest_reg;
                writeback_is_last_subcycle_nxt = is_last_subcycle_mx;
            end

            //
            // Integer pipeline result
            //
            3'b010:
            begin
                if (ix_instruction.is_branch
                    && (ix_instruction.branch_type == BRANCH_CALL_OFFSET
                    || ix_instruction.branch_type == BRANCH_CALL_REGISTER))
                begin
                    // Call is a special case: it both rolls back and writes
                    // back a register (ra)
                    writeback_en_nxt = 1;
                end
                else if (ix_instruction.has_dest && !wb_rollback_en)
                begin
                    // This is a normal, non-rolled-back instruction
                    writeback_en_nxt = 1;
                end

                writeback_thread_idx_nxt = ix_thread_idx;
                writeback_mask_nxt = ix_mask_value;
                if (ix_instruction.is_call)
                    writeback_value_nxt = vector_t'(ix_instruction.pc + 32'd4);
                else if (ix_instruction.is_compare)
                    writeback_value_nxt = vector_t'(scycle_vcompare_result);
                else
                    writeback_value_nxt = ix_result;

                writeback_is_vector_nxt = ix_instruction.dest_is_vector;
                writeback_reg_nxt = ix_instruction.dest_reg;
                writeback_is_last_subcycle_nxt = is_last_subcycle_sx;
            end

            //
            // Memory pipeline result
            //
            3'b001:
            begin
                writeback_en_nxt = dd_instruction.has_dest && !wb_rollback_en;
                writeback_thread_idx_nxt = dd_thread_idx;
                if (!dd_instruction.is_cache_control)
                begin
                    if (dd_instruction.is_load)
                    begin
                        unique case (memory_op)
                            MEM_B:      writeback_value_nxt[0] = scalar_t'(byte_aligned);
                            MEM_BX:     writeback_value_nxt[0] = scalar_t'($signed(byte_aligned));
                            MEM_S:      writeback_value_nxt[0] = scalar_t'(half_aligned);
                            MEM_SX:     writeback_value_nxt[0] = scalar_t'($signed(half_aligned));
                            MEM_SYNC:   writeback_value_nxt[0] = swapped_word_value;
                            MEM_L:
                            begin
                                // Scalar Load
                                if (dd_is_io_address)
                                begin
                                    writeback_mask_nxt = {NUM_VECTOR_LANES{1'b1}};
                                    writeback_value_nxt[0] = ior_read_value;
                                end
                                else
                                begin
                                    writeback_mask_nxt = {NUM_VECTOR_LANES{1'b1}};
                                    writeback_value_nxt[0] = swapped_word_value;
                                end
                            end

                            MEM_CONTROL_REG:
                            begin
                                writeback_mask_nxt = {NUM_VECTOR_LANES{1'b1}};
                                writeback_value_nxt[0] = cr_creg_read_val;
                            end

                            MEM_BLOCK,
                            MEM_BLOCK_M:
                            begin
                                writeback_mask_nxt = dd_lane_mask;
                                writeback_value_nxt = endian_twiddled_data;
                            end

                            default:
                            begin
                                // Gather load
                                // Grab the appropriate lane.
                                writeback_mask_nxt = dd_vector_lane_oh & dd_lane_mask;
                                writeback_value_nxt = {NUM_VECTOR_LANES{swapped_word_value}};
                            end
                        endcase
                    end
                    else if (memory_op == MEM_SYNC)
                    begin
                        // Synchronized stores are special because they write
                        // back (whether they were successful).
                        writeback_value_nxt[0] = scalar_t'(sq_store_sync_success);
                    end
                end

                writeback_is_vector_nxt = dd_instruction.dest_is_vector;
                writeback_reg_nxt = dd_instruction.dest_reg;
                writeback_is_last_subcycle_nxt = is_last_subcycle_dd;
            end

            default:
                ;
        endcase
    end

    always_ff @(posedge clk)
    begin
        wb_writeback_thread_idx <= writeback_thread_idx_nxt;
        wb_writeback_mask <= writeback_mask_nxt;
        wb_writeback_value <= writeback_value_nxt;
        wb_writeback_is_vector <= writeback_is_vector_nxt;
        wb_writeback_reg <= writeback_reg_nxt;
        wb_writeback_is_last_subcycle <= writeback_is_last_subcycle_nxt;
    end

    always_ff @(posedge clk, posedge reset)
    begin
        if (reset)
            wb_writeback_en <= 0;
        else
        begin
            // Don't cause rollback if there isn't an instruction
            assert(!(sq_rollback_en && !dd_instruction_valid));

            // Only one pipeline should attempt to retire an instruction per cycle
            assert($onehot0({ix_instruction_valid, dd_instruction_valid, fx5_instruction_valid}));

`ifdef SIMULATION
            if (dd_instruction_valid && !dd_instruction.is_cache_control)
            begin
                if (dd_instruction.is_load)
                begin
                    // Loads should always have a destination register.
                    assert(dd_instruction.has_dest);

                    if (memory_op == MEM_B || memory_op == MEM_BX || memory_op == MEM_S
                        || memory_op == MEM_SX || memory_op == MEM_SYNC || memory_op == MEM_L
                        || memory_op == MEM_CONTROL_REG)
                    begin
                        // Must be scalar destination
                        assert(!dd_instruction.dest_is_vector);
                    end
                    else
                        assert(dd_instruction.dest_is_vector);
                end
                else if (memory_op == MEM_SYNC)
                begin
                    // Synchronized stores are special because they write back (whether they
                    // were successful).
                    assert(dd_instruction.has_dest && !dd_instruction.dest_is_vector);
                end
            end
`endif

            wb_writeback_en <= writeback_en_nxt;
        end
    end

`ifdef SIMULATION
    always_ff @(posedge clk)
    begin
        if (wb_rollback_en && wb_rollback_pc == 0)
        begin
            $display("thread %0d rolled back to 0, cause %0d address %08x", wb_rollback_thread_idx,
                wb_trap_cause, wb_trap_pc);
            $finish;
        end

        // Used by testbench for cosimulation output
        __debug_is_sync_store <= dd_instruction_valid && !dd_instruction.is_load
            && memory_op == MEM_SYNC;
        case ({fx5_instruction_valid, ix_instruction_valid, dd_instruction_valid})
            3'b100:
            begin
                __debug_wb_pc <= fx5_instruction.pc;
                __debug_wb_pipeline <= PIPE_FLOAT_ARITH;
            end

            3'b010:
            begin
                __debug_wb_pc <= ix_instruction.pc;
                __debug_wb_pipeline <= PIPE_INT_ARITH;
            end

            3'b001:
            begin
                __debug_wb_pc <= dd_instruction.pc;
                __debug_wb_pipeline <= PIPE_MEM;
            end

            default:
                ;
        endcase
    end
`endif
endmodule
