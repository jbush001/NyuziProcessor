//
// Copyright 2018 Jeff Bush
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

module test_writeback_stage(input clk, input reset);
    localparam RESULT0 = 512'hc15bc3d97ebadf04f3754c0434ebef01d38de1280edbccf9ee36223e001fdf7efbf4dcfdb09130fd194b1bae6dfe0112817593e1b96b0e7383cd8ef45f0d36ca;
    localparam RESULT1 = 512'hffffffff00000000000000000000000000000000ffffffffffffffff00000000ffffffffffffffff000000000000000000000000ffffffff00000000ffffffff;
    localparam BITMASK1 = 16'b1010001101100001; // Bit order is reversed from above
    localparam RESULT2 = 512'h573416c50f9be6d18fcaca45f9612824e5db199969fc65e849c2e44dce33744fe98aed2b105656fe075be9e08e1a8fb8276e87b133a6dfd5349d27c632d516bf;
    localparam RESULT3 = 512'h00000000ffffffffffffffff0000000000000000ffffffff00000000000000000000000000000000ffffffffffffffffffffffff000000000000000000000000;
    localparam BITMASK3 = 16'b0001110000100110;
    localparam RESULT4 = 512'h3a9030d560d9ef341e0913dbee69ba02c9f446552574ce195b2f080e7af31a9ff8e26034d9ac6fe8ddc0e02283915ea62ca664a4267fd74d822d0e0bbf6cebdf;
    localparam TRAP_CAUSE1 = {2'b00, TT_ILLEGAL_INSTRUCTION};
    localparam TRAP_CAUSE2 = {2'b00, TT_UNALIGNED_ACCESS};
    localparam PRIVILEGED_OP_CAUSE = {2'b00, TT_PRIVILEGED_OP};
    localparam TLB_MISS_CAUSE = {2'b00, TT_TLB_MISS};
    localparam INTERRUPT_CAUSE = {2'b00, TT_INTERRUPT};
    localparam TRAP_HANDLER1 = 32'h2b6605ba;
    localparam TRAP_HANDLER2 = 32'h96b988d4;
    localparam TRAP_HANDLER3 = 32'hb3fe6b30;
    localparam TRAP_HANDLER4 = 32'hced7be16;
    localparam PC1 = 32'hb4835ca4;
    localparam PC2 = 32'had261818;
    localparam PC3 = 32'hbb51be84;
    localparam PC4 = 32'h1cf54bf8;
    localparam PC5 = 32'haa0a17c8;
    localparam PC6 = 32'h95df7380;
    localparam PC7 = 32'hc5346f44;
    localparam PC8 = 32'he2fb8974;
    localparam ACCESS_ADDR1 = 32'he814c094;
    localparam ACCESS_ADDR2 = 32'h6ebf3224;

    logic fx5_instruction_valid;
    decoded_instruction_t fx5_instruction;
    vector_t fx5_result;
    vector_mask_t fx5_mask_value;
    local_thread_idx_t fx5_thread_idx;
    subcycle_t fx5_subcycle;
    logic ix_instruction_valid;
    decoded_instruction_t ix_instruction;
    vector_t ix_result;
    local_thread_idx_t ix_thread_idx;
    vector_mask_t ix_mask_value;
    logic ix_rollback_en;
    scalar_t ix_rollback_pc;
    subcycle_t ix_subcycle;
    logic ix_privileged_op_fault;
    logic dd_instruction_valid;
    decoded_instruction_t dd_instruction;
    vector_mask_t dd_lane_mask;
    local_thread_idx_t dd_thread_idx;
    l1d_addr_t dd_request_vaddr;
    subcycle_t dd_subcycle;
    logic dd_rollback_en;
    scalar_t dd_rollback_pc;
    cache_line_data_t dd_load_data;
    logic dd_suspend_thread;
    logic dd_io_access;
    logic dd_trap;
    trap_cause_t dd_trap_cause;
    logic[CACHE_LINE_BYTES - 1:0] sq_store_bypass_mask;
    cache_line_data_t sq_store_bypass_data;
    logic sq_store_sync_success;
    logic sq_rollback_en;
    scalar_t ior_read_value;
    logic ior_rollback_en;
    scalar_t cr_creg_read_val;
    scalar_t cr_trap_handler;
    scalar_t cr_tlb_miss_handler;
    subcycle_t cr_eret_subcycle[`THREADS_PER_CORE];
    logic wb_trap;
    trap_cause_t wb_trap_cause;
    scalar_t wb_trap_pc;
    scalar_t wb_trap_access_vaddr;
    subcycle_t wb_trap_subcycle;
    logic wb_eret;
    logic wb_rollback_en;
    local_thread_idx_t wb_rollback_thread_idx;
    scalar_t wb_rollback_pc;
    pipeline_sel_t wb_rollback_pipeline;
    subcycle_t wb_rollback_subcycle;
    logic wb_writeback_en;
    local_thread_idx_t wb_writeback_thread_idx;
    logic wb_writeback_vector;
    vector_t wb_writeback_value;
    vector_mask_t wb_writeback_mask;
    register_idx_t wb_writeback_reg;
    logic wb_writeback_last_subcycle;
    local_thread_bitmap_t wb_suspend_thread_oh;
    logic wb_inst_injected;
    logic wb_perf_instruction_retire;
    logic wb_perf_store_rollback;
    logic wb_perf_interrupt;
    int cycle;

    writeback_stage writeback_stage(.*);

    assign fx5_thread_idx = 1;
    assign dd_thread_idx = 2;
    assign ix_thread_idx = 3;

    always_ff @(posedge clk, posedge reset)
    begin
        if (reset)
        begin
            cycle <= 0;
            fx5_result <= '0;
            fx5_mask_value <= '0;
            fx5_subcycle <= '0;
            ix_result <= '0;
            ix_thread_idx <= '0;
            ix_mask_value <= '0;
            ix_rollback_pc <= '0;
            ix_subcycle <= '0;
            dd_lane_mask <= '0;
            dd_thread_idx <= '0;
            dd_request_vaddr <= '0;
            dd_subcycle <= '0;
            dd_rollback_pc <= '0;
            dd_load_data <= '0;
            dd_io_access <= '0;
            dd_trap_cause <= '0;
            sq_store_bypass_mask <= '0;
            sq_store_bypass_data <= '0;
            sq_store_sync_success <= '0;
            ior_read_value <= '0;
            cr_creg_read_val <= '0;
            cr_trap_handler <= '0;
            cr_tlb_miss_handler <= '0;
            for (int i = 0; i < `THREADS_PER_CORE; i++)
                cr_eret_subcycle[i] <= '0;
        end
        else
        begin
            fx5_instruction_valid <= '0;
            ix_instruction_valid <= '0;
            dd_instruction_valid <= '0;
            dd_rollback_en <= '0;
            sq_rollback_en <= '0;
            ior_rollback_en <= '0;
            dd_suspend_thread <= '0;
            ix_rollback_en <= '0;
            dd_trap <= '0;
            ix_instruction <= '0;
            fx5_instruction <= '0;
            dd_instruction <= '0;
            ix_privileged_op_fault <= '0;

            cycle <= cycle + 1;
            unique0 case (cycle)
                ////////////////////////////////////////////////////////////
                // Normal integer retire
                ////////////////////////////////////////////////////////////
                0:
                begin
                    ix_instruction_valid <= 1;
                    ix_instruction.has_dest <= 1;
                    ix_instruction.dest_reg <= 7;
                    ix_result <= RESULT0;
                end

                1:
                begin
                    assert(!wb_trap);
                    assert(!wb_eret);
                    assert(!wb_rollback_en);
                    assert(!wb_writeback_en);
                    assert(wb_suspend_thread_oh == 0);
                    assert(!wb_perf_instruction_retire);
                    assert(!wb_perf_store_rollback);
                    assert(!wb_perf_interrupt);
                end

                2:
                begin
                    assert(!wb_trap);
                    assert(!wb_eret);
                    assert(!wb_rollback_en);
                    assert(wb_writeback_en);
                    assert(wb_writeback_thread_idx == 3);
                    assert(!wb_writeback_vector);
                    assert(wb_writeback_value == RESULT0);
                    assert(wb_writeback_reg == 7);
                    assert(wb_writeback_last_subcycle);
                    assert(wb_suspend_thread_oh == 0);
                    assert(!wb_inst_injected);
                    assert(wb_perf_instruction_retire);
                    assert(!wb_perf_store_rollback);
                    assert(!wb_perf_interrupt);
                end

                ////////////////////////////////////////////////////////////
                // Integer comparison
                ////////////////////////////////////////////////////////////
                3:
                begin
                    ix_instruction_valid <= 1;
                    ix_instruction.has_dest <= 1;
                    ix_instruction.dest_reg <= 9;
                    ix_instruction.compare <= 1;
                    ix_result <= RESULT1;
                end

                4:
                begin
                    assert(!wb_trap);
                    assert(!wb_eret);
                    assert(!wb_rollback_en);
                    assert(!wb_writeback_en);
                    assert(wb_suspend_thread_oh == 0);
                    assert(!wb_perf_instruction_retire);
                    assert(!wb_perf_store_rollback);
                    assert(!wb_perf_interrupt);
                end

                5:
                begin
                    assert(!wb_trap);
                    assert(!wb_eret);
                    assert(!wb_rollback_en);
                    assert(wb_writeback_en);
                    assert(wb_writeback_thread_idx == 3);
                    assert(!wb_writeback_vector);
                    assert(wb_writeback_reg == 9);
                    assert(wb_writeback_last_subcycle);
                    assert(wb_suspend_thread_oh == 0);
                    assert(!wb_inst_injected);
                    assert(wb_perf_instruction_retire);
                    assert(!wb_perf_store_rollback);
                    assert(!wb_perf_interrupt);

                    // Ensure this compresses the lanes down to a bitmask
                    assert(wb_writeback_value[0][15:0] == BITMASK1);
                end

                ////////////////////////////////////////////////////////////
                // Normal floating point retire
                ////////////////////////////////////////////////////////////
                6:
                begin
                    fx5_instruction_valid <= 1;
                    fx5_instruction.has_dest <= 1;
                    fx5_instruction.dest_reg <= 7;
                    fx5_result <= RESULT2;
                end

                7:
                begin
                    assert(!wb_trap);
                    assert(!wb_eret);
                    assert(!wb_rollback_en);
                    assert(!wb_writeback_en);
                    assert(wb_suspend_thread_oh == 0);
                    assert(!wb_perf_instruction_retire);
                    assert(!wb_perf_store_rollback);
                end

                8:
                begin
                    assert(!wb_trap);
                    assert(!wb_eret);
                    assert(!wb_rollback_en);
                    assert(wb_writeback_en);
                    assert(wb_writeback_thread_idx == 1);
                    assert(!wb_writeback_vector);
                    assert(wb_writeback_value == RESULT2);
                    assert(wb_writeback_reg == 7);
                    assert(wb_writeback_last_subcycle);
                    assert(wb_suspend_thread_oh == 0);
                    assert(!wb_inst_injected);
                    assert(wb_perf_instruction_retire);
                    assert(!wb_perf_store_rollback);
                    assert(!wb_perf_interrupt);
                end

                ////////////////////////////////////////////////////////////
                // Floating point comparison
                ////////////////////////////////////////////////////////////
                9:
                begin
                    fx5_instruction_valid <= 1;
                    fx5_instruction.has_dest <= 1;
                    fx5_instruction.dest_reg <= 11;
                    fx5_instruction.compare <= 1;
                    fx5_result <= RESULT3;
                end

                10:
                begin
                    assert(!wb_trap);
                    assert(!wb_eret);
                    assert(!wb_rollback_en);
                    assert(!wb_writeback_en);
                    assert(wb_suspend_thread_oh == 0);
                    assert(!wb_perf_instruction_retire);
                    assert(!wb_perf_store_rollback);
                end

                11:
                begin
                    assert(!wb_trap);
                    assert(!wb_eret);
                    assert(!wb_rollback_en);
                    assert(wb_writeback_en);
                    assert(wb_writeback_thread_idx == 1);
                    assert(!wb_writeback_vector);
                    assert(wb_writeback_reg == 11);
                    assert(wb_writeback_last_subcycle);
                    assert(wb_suspend_thread_oh == 0);
                    assert(!wb_inst_injected);
                    assert(wb_perf_instruction_retire);
                    assert(!wb_perf_store_rollback);
                    assert(!wb_perf_interrupt);

                    // Ensure this compresses the lanes down to a bitmask
                    assert(wb_writeback_value[0][15:0] == BITMASK3);
                end

                ////////////////////////////////////////////////////////////
                // Normal memory pipeline retire
                ////////////////////////////////////////////////////////////
                12:
                begin
                    dd_instruction_valid <= 1;
                    dd_instruction.has_dest <= 1;
                    dd_instruction.dest_reg <= 3;
                    dd_instruction.memory_access_type <= MEM_S;
                    dd_instruction.load <= 1;
                    dd_load_data <= RESULT4;
                    dd_request_vaddr <= 4;
                end

                13:
                begin
                    assert(!wb_trap);
                    assert(!wb_eret);
                    assert(!wb_rollback_en);
                    assert(!wb_writeback_en);
                    assert(wb_suspend_thread_oh == 0);
                    assert(!wb_perf_instruction_retire);
                    assert(!wb_perf_store_rollback);
                end

                14:
                begin
                    assert(!wb_trap);
                    assert(!wb_eret);
                    assert(!wb_rollback_en);
                    assert(wb_writeback_en);
                    assert(wb_writeback_thread_idx == 2);
                    assert(!wb_writeback_vector);
                    assert(wb_writeback_reg == 3);
                    assert(wb_writeback_last_subcycle);
                    assert(wb_suspend_thread_oh == 0);
                    assert(!wb_inst_injected);
                    assert(wb_perf_instruction_retire);
                    assert(!wb_perf_store_rollback);
                    assert(!wb_perf_interrupt);

                    assert(wb_writeback_value[0][31:0] == 32'h0000d960);
                end

                ////////////////////////////////////////////////////////////
                // Fault piggybacked on integer instruction
                ////////////////////////////////////////////////////////////
                15:
                begin
                    ix_instruction_valid <= 1;
                    ix_instruction.has_dest <= 1;
                    ix_instruction.dest_reg <= 7;
                    ix_instruction.has_trap <= 1;
                    ix_instruction.trap_cause <= TRAP_CAUSE1;
                    cr_trap_handler <= TRAP_HANDLER1;
                    ix_instruction.pc <= PC5;
                end

                16:
                begin
                    assert(wb_trap);
                    assert(wb_trap_cause == TRAP_CAUSE1);
                    assert(wb_trap_pc == PC5);
                    assert(wb_trap_access_vaddr == PC5);
                    assert(wb_trap_subcycle == 0);
                    assert(!wb_eret);
                    assert(wb_rollback_en);
                    assert(wb_rollback_thread_idx == 3);
                    assert(wb_rollback_pc == TRAP_HANDLER1);
                    assert(wb_rollback_pipeline == PIPE_INT_ARITH);
                    assert(wb_rollback_subcycle == 0);
                    assert(!wb_writeback_en);
                    assert(wb_suspend_thread_oh == 0);
                    assert(!wb_inst_injected);
                    assert(!wb_perf_instruction_retire);
                    assert(!wb_perf_store_rollback);
                    assert(!wb_perf_interrupt);
                end

                17:
                begin
                    // Ensure this doesn't try to perform a writeback
                    assert(!wb_writeback_en);
                    assert(wb_suspend_thread_oh == 0);
                    assert(!wb_inst_injected);
                    assert(!wb_perf_instruction_retire);
                    assert(!wb_perf_store_rollback);
                    assert(!wb_perf_interrupt);
                end

                ////////////////////////////////////////////////////////////
                // Trap from memory pipeline
                ////////////////////////////////////////////////////////////
                18:
                begin
                    dd_instruction_valid <= 1;
                    dd_instruction.has_dest <= 1;
                    dd_instruction.dest_reg <= 3;
                    dd_instruction.memory_access_type <= MEM_S;
                    dd_instruction.load <= 1;
                    dd_instruction.pc <= PC5;
                    dd_trap <= 1;
                    dd_trap_cause <= TRAP_CAUSE2;
                    cr_trap_handler <= TRAP_HANDLER2;
                    dd_request_vaddr <= ACCESS_ADDR2;
                end

                19:
                begin
                    assert(wb_trap);
                    assert(wb_trap_cause == TRAP_CAUSE2);
                    assert(wb_trap_pc == PC5);
                    assert(wb_trap_access_vaddr == ACCESS_ADDR2);
                    assert(wb_trap_subcycle == 0);
                    assert(!wb_eret);
                    assert(wb_rollback_en);
                    assert(wb_rollback_thread_idx == 2);
                    assert(wb_rollback_pc == TRAP_HANDLER2);
                    assert(wb_rollback_pipeline == PIPE_MEM);
                    assert(wb_rollback_subcycle == 0);
                    assert(!wb_writeback_en);
                    assert(wb_suspend_thread_oh == 0);
                    assert(!wb_inst_injected);
                    assert(!wb_perf_instruction_retire);
                    assert(!wb_perf_store_rollback);
                    assert(!wb_perf_interrupt);
                end

                20:
                begin
                    assert(!wb_trap);
                    assert(!wb_eret);
                    assert(!wb_rollback_en);
                    assert(!wb_writeback_en);
                    assert(wb_suspend_thread_oh == 0);
                    assert(!wb_inst_injected);
                    assert(!wb_perf_instruction_retire);
                    assert(!wb_perf_store_rollback);
                    assert(!wb_perf_interrupt);
                end

                ////////////////////////////////////////////////////////////
                // Rollback from memory pipeline because of cache miss
                ////////////////////////////////////////////////////////////
                21:
                begin
                    dd_instruction_valid <= 1;
                    dd_instruction.has_dest <= 1;
                    dd_instruction.dest_reg <= 3;
                    dd_instruction.memory_access_type <= MEM_S;
                    dd_instruction.load <= 1;
                    dd_rollback_en <= 1;
                    dd_rollback_pc <= PC1;
                    dd_suspend_thread <= 1;
                end

                22:
                begin
                    assert(!wb_trap);
                    assert(!wb_eret);
                    assert(wb_rollback_en);
                    assert(wb_rollback_thread_idx == 2);
                    assert(wb_rollback_pc == PC1);
                    assert(wb_rollback_pipeline == PIPE_MEM);
                    assert(wb_rollback_subcycle == 0);
                    assert(!wb_writeback_en);
                    assert(wb_suspend_thread_oh == 4'b0100);
                    assert(!wb_inst_injected);
                    assert(!wb_perf_instruction_retire);
                    assert(!wb_perf_store_rollback);
                    assert(!wb_perf_interrupt);
                end

                23:
                begin
                    assert(!wb_trap);
                    assert(!wb_eret);
                    assert(!wb_rollback_en);
                    assert(!wb_writeback_en);
                    assert(wb_suspend_thread_oh == 0);
                    assert(!wb_inst_injected);
                    assert(!wb_perf_instruction_retire);
                    assert(!wb_perf_store_rollback);
                    assert(!wb_perf_interrupt);
                end

                ////////////////////////////////////////////////////////////
                // Trap from memory pipeline because of TLB miss
                ////////////////////////////////////////////////////////////
                24:
                begin
                    dd_instruction_valid <= 1;
                    dd_instruction.has_dest <= 1;
                    dd_instruction.dest_reg <= 3;
                    dd_instruction.memory_access_type <= MEM_S;
                    dd_instruction.load <= 1;
                    dd_instruction.pc <= PC6;
                    dd_trap <= 1;
                    dd_trap_cause <= TLB_MISS_CAUSE;
                    cr_tlb_miss_handler <= TRAP_HANDLER3;
                    dd_request_vaddr <= ACCESS_ADDR1;
                end

                25:
                begin
                    assert(wb_trap);
                    assert(wb_trap_cause == TLB_MISS_CAUSE);
                    assert(wb_trap_pc == PC6);
                    assert(wb_trap_access_vaddr == ACCESS_ADDR1);
                    assert(wb_trap_subcycle == 0);
                    assert(!wb_eret);
                    assert(wb_rollback_en);
                    assert(wb_rollback_thread_idx == 2);
                    assert(wb_rollback_pc == TRAP_HANDLER3);
                    assert(wb_rollback_pipeline == PIPE_MEM);
                    assert(wb_rollback_subcycle == 0);
                    assert(!wb_writeback_en);
                    assert(wb_suspend_thread_oh == 0);
                    assert(!wb_inst_injected);
                    assert(!wb_perf_instruction_retire);
                    assert(!wb_perf_store_rollback);
                    assert(!wb_perf_interrupt);
                end

                26:
                begin
                    assert(!wb_trap);
                    assert(!wb_eret);
                    assert(!wb_rollback_en);
                    assert(!wb_writeback_en);
                    assert(wb_suspend_thread_oh == 0);
                    assert(!wb_inst_injected);
                    assert(!wb_perf_instruction_retire);
                    assert(!wb_perf_store_rollback);
                    assert(!wb_perf_interrupt);
                end

                ////////////////////////////////////////////////////////////
                // Rollback from integer pipeline (branch)
                ////////////////////////////////////////////////////////////
                27:
                begin
                    ix_instruction_valid <= 1;
                    ix_instruction.has_dest <= 1;
                    ix_instruction.dest_reg <= 7;
                    ix_instruction.branch <= 1;
                    ix_instruction.branch_type <= BRANCH_ALWAYS;
                    ix_rollback_en <= 1;
                    ix_rollback_pc <= PC2;
                end

                28:
                begin
                    assert(!wb_trap);
                    assert(!wb_eret);
                    assert(wb_rollback_en);
                    assert(wb_rollback_thread_idx == 3);
                    assert(wb_rollback_pc == PC2);
                    assert(wb_rollback_pipeline == PIPE_INT_ARITH);
                    assert(wb_rollback_subcycle == 0);
                    assert(!wb_writeback_en);
                    assert(wb_suspend_thread_oh == 0);
                    assert(!wb_inst_injected);
                    assert(!wb_perf_instruction_retire);
                    assert(!wb_perf_store_rollback);
                    assert(!wb_perf_interrupt);
                end

                29:
                begin
                    assert(!wb_trap);
                    assert(!wb_eret);
                    assert(!wb_rollback_en);
                    assert(!wb_writeback_en);
                    assert(wb_suspend_thread_oh == 0);
                    assert(!wb_inst_injected);
                    assert(wb_perf_instruction_retire);
                    assert(!wb_perf_store_rollback);
                    assert(!wb_perf_interrupt);
                end

                ////////////////////////////////////////////////////////////
                // Eret
                ////////////////////////////////////////////////////////////
                30:
                begin
                    ix_instruction_valid <= 1;
                    ix_instruction.has_dest <= 1;
                    ix_instruction.dest_reg <= 7;
                    ix_instruction.branch <= 1;
                    ix_instruction.branch_type <= BRANCH_ERET;
                    ix_rollback_en <= 1;
                    ix_rollback_pc <= PC2;
                end

                31:
                begin
                    assert(!wb_trap);
                    assert(wb_eret);
                    assert(wb_rollback_en);
                    assert(wb_rollback_thread_idx == 3);
                    assert(wb_rollback_pc == PC2);
                    assert(wb_rollback_pipeline == PIPE_INT_ARITH);
                    assert(wb_rollback_subcycle == 0);
                    assert(!wb_writeback_en);
                    assert(wb_suspend_thread_oh == 0);
                    assert(!wb_inst_injected);
                    assert(!wb_perf_instruction_retire);
                    assert(!wb_perf_store_rollback);
                    assert(!wb_perf_interrupt);
                end

                32:
                begin
                    assert(!wb_trap);
                    assert(!wb_eret);
                    assert(!wb_rollback_en);
                    assert(!wb_writeback_en);
                    assert(wb_suspend_thread_oh == 0);
                    assert(!wb_inst_injected);
                    assert(wb_perf_instruction_retire);
                    assert(!wb_perf_store_rollback);
                    assert(!wb_perf_interrupt);
                end

                ////////////////////////////////////////////////////////////
                // Call
                ////////////////////////////////////////////////////////////
                33:
                begin
                    ix_instruction_valid <= 1;
                    ix_instruction.has_dest <= 1;
                    ix_instruction.dest_reg <= 31;
                    ix_instruction.branch <= 1;
                    ix_instruction.branch_type <= BRANCH_CALL_OFFSET;
                    ix_instruction.pc <= PC4;
                    ix_instruction.call <= 1;
                    ix_rollback_en <= 1;
                    ix_rollback_pc <= PC3;
                end

                34:
                begin
                    assert(!wb_trap);
                    assert(!wb_eret);
                    assert(wb_rollback_en);
                    assert(wb_rollback_thread_idx == 3);
                    assert(wb_rollback_pc == PC3);
                    assert(wb_rollback_pipeline == PIPE_INT_ARITH);
                    assert(wb_rollback_subcycle == 0);
                    assert(!wb_writeback_en);
                    assert(wb_suspend_thread_oh == 0);
                    assert(!wb_perf_instruction_retire);
                    assert(!wb_perf_store_rollback);
                end

                35:
                begin
                    assert(!wb_trap);
                    assert(!wb_rollback_en);
                    assert(wb_writeback_en);
                    assert(wb_writeback_thread_idx == 3);
                    assert(!wb_writeback_vector);
                    assert(wb_writeback_value[0] == PC4 + 4);
                    assert(wb_writeback_reg == 31);
                    assert(wb_writeback_last_subcycle);
                    assert(wb_suspend_thread_oh == 0);
                    assert(!wb_inst_injected);
                    assert(wb_perf_instruction_retire);
                    assert(!wb_perf_store_rollback);
                    assert(!wb_perf_interrupt);
                end

                ////////////////////////////////////////////////////////////
                // Privileged op fault from integer pipeline
                ////////////////////////////////////////////////////////////
                36:
                begin
                    ix_instruction_valid <= 1;
                    ix_instruction.has_dest <= 1;
                    ix_instruction.branch <= 1;
                    ix_instruction.branch_type <= BRANCH_ERET;
                    ix_instruction.pc <= PC7;
                    ix_rollback_en <= 1;
                    ix_privileged_op_fault <= 1;
                    cr_trap_handler <= TRAP_HANDLER4;
                end

                37:
                begin
                    assert(wb_trap);
                    assert(wb_trap_cause == PRIVILEGED_OP_CAUSE);
                    assert(wb_trap_pc == PC7);
                    assert(wb_trap_subcycle == 0);
                    assert(!wb_eret);
                    assert(wb_rollback_en);
                    assert(wb_rollback_thread_idx == 3);
                    assert(wb_rollback_pc == TRAP_HANDLER4);
                    assert(wb_rollback_pipeline == PIPE_INT_ARITH);
                    assert(wb_rollback_subcycle == 0);
                    assert(!wb_writeback_en);
                    assert(wb_suspend_thread_oh == 0);
                    assert(!wb_inst_injected);
                    assert(!wb_perf_instruction_retire);
                    assert(!wb_perf_store_rollback);
                    assert(!wb_perf_interrupt);
                end

                38:
                begin
                    // Ensure this doesn't try to perform a writeback
                    assert(!wb_writeback_en);
                    assert(wb_suspend_thread_oh == 0);
                    assert(!wb_inst_injected);
                    assert(!wb_perf_instruction_retire);
                    assert(!wb_perf_store_rollback);
                    assert(!wb_perf_interrupt);
                end

                ////////////////////////////////////////////////////////////
                // Interrupt
                ////////////////////////////////////////////////////////////
                39:
                begin
                    ix_instruction_valid <= 1;
                    ix_instruction.has_dest <= 1;
                    cr_trap_handler <= TRAP_HANDLER1;
                    ix_instruction.has_trap <= 1;
                    ix_instruction.trap_cause <= INTERRUPT_CAUSE;
                    ix_instruction.pc <= PC8;
                end

                40:
                begin
                    assert(wb_trap);
                    assert(wb_trap_cause == INTERRUPT_CAUSE);
                    assert(wb_trap_pc == PC8);
                    assert(wb_trap_subcycle == 0);
                    assert(!wb_eret);
                    assert(wb_rollback_en);
                    assert(wb_rollback_thread_idx == 3);
                    assert(wb_rollback_pc == TRAP_HANDLER1);
                    assert(wb_rollback_pipeline == PIPE_INT_ARITH);
                    assert(wb_rollback_subcycle == 0);
                    assert(!wb_writeback_en);
                    assert(wb_suspend_thread_oh == 0);
                    assert(!wb_inst_injected);
                    assert(!wb_perf_instruction_retire);
                    assert(!wb_perf_store_rollback);
                    assert(!wb_perf_interrupt);
                end

                41:
                begin
                    // Ensure this doesn't try to perform a writeback
                    assert(!wb_writeback_en);
                    assert(wb_suspend_thread_oh == 0);
                    assert(!wb_inst_injected);
                    assert(!wb_perf_instruction_retire);
                    assert(!wb_perf_store_rollback);
                    assert(wb_perf_interrupt);
                end

                // Done
                42:
                begin
                    $display("PASS");
                    $finish;
                end
            endcase
        end
    end
endmodule
