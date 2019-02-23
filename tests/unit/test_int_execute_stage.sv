//
// Copyright 2017 Jeff Bush
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

module test_int_execute_stage(input clk, input reset);
    localparam ERET_ADDR = 'h12340020;
    localparam BRANCH_ADDR0 = 'h83740350;
    localparam BRANCH_ADDR1 = 'haab62510;

    vector_t of_operand1;
    vector_t of_operand2;
    vector_mask_t of_mask_value;
    logic of_instruction_valid;
    decoded_instruction_t of_instruction;
    local_thread_idx_t of_thread_idx;
    subcycle_t of_subcycle;
    logic wb_rollback_en;
    local_thread_idx_t wb_rollback_thread_idx;
    logic ix_instruction_valid;
    decoded_instruction_t ix_instruction;
    vector_t ix_result;
    vector_mask_t ix_mask_value;
    local_thread_idx_t ix_thread_idx;
    logic ix_rollback_en;
    scalar_t ix_rollback_pc;
    subcycle_t ix_subcycle;
    logic ix_privileged_op_fault;
    scalar_t cr_eret_address[`THREADS_PER_CORE];
    logic cr_supervisor_en[`THREADS_PER_CORE];
    logic ix_perf_uncond_branch;
    logic ix_perf_cond_branch_taken;
    logic ix_perf_cond_branch_not_taken;
    int cycle;
    scalar_t last_branch_pc;
    scalar_t last_branch_offset;

    int_execute_stage int_execute_stage(.*);

    task branch(input branch_type_t branch_type, input scalar_t regval);
        scalar_t pc = $random() & ~3;
        scalar_t offset = $random() & ~3;
        of_instruction_valid <= 1;
        of_instruction.branch <= 1;
        of_instruction.branch_type <= branch_type;
        of_instruction.pipeline_sel <= PIPE_INT_ARITH;
        of_operand1[0] <= regval;
        last_branch_pc <= pc;
        last_branch_offset <= offset;
        of_instruction.pc <= pc;
        of_instruction.immediate_value <= offset;
    endtask

    always_ff @(posedge clk, posedge reset)
    begin
        if (reset)
        begin
            cycle <= 0;
            of_operand1 <= '0;
            of_operand2 <= '0;
            of_mask_value <= '0;
            of_thread_idx <= '0;
            of_subcycle <= '0;
            wb_rollback_thread_idx <= '0;
            for (int i = 0; i < `THREADS_PER_CORE; i++)
                cr_eret_address[i] <= '0;

            for (int i = 0; i < `THREADS_PER_CORE; i++)
                cr_supervisor_en[i] <= '0;
        end
        else
        begin
            wb_rollback_en <= '0;
            of_instruction <= '0;
            of_instruction_valid <= '0;

            cycle <= cycle + 1;
            unique0 case (cycle)
                ////////////////////////////////////////////////////////////
                // Eret from user mode. This will fault.
                ////////////////////////////////////////////////////////////
                0:
                begin
                    branch(BRANCH_ERET, 0);
                    assert(!ix_perf_uncond_branch);
                    assert(!ix_perf_cond_branch_taken);
                    assert(!ix_perf_cond_branch_not_taken);
                end

                1:
                begin
                    assert(!ix_perf_uncond_branch);
                    assert(!ix_perf_cond_branch_taken);
                    assert(!ix_perf_cond_branch_not_taken);
                end


                2:
                begin
                    assert(ix_privileged_op_fault);
                    assert(!ix_perf_uncond_branch);
                    assert(!ix_perf_cond_branch_taken);
                    assert(!ix_perf_cond_branch_not_taken);
                end

                ////////////////////////////////////////////////////////////
                // Eret from supervisor mode (will not fault)
                ////////////////////////////////////////////////////////////
                3:
                begin
                    branch(BRANCH_ERET, 0);
                    cr_supervisor_en[0] <= 1;
                    cr_eret_address[0] <= ERET_ADDR;
                    cr_eret_address[1] <= $random();
                    cr_eret_address[2] <= $random();
                    cr_eret_address[3] <= $random();
                    assert(!ix_perf_uncond_branch);
                    assert(!ix_perf_cond_branch_taken);
                    assert(!ix_perf_cond_branch_not_taken);
                end

                4:
                begin
                    assert(!ix_perf_uncond_branch);
                    assert(!ix_perf_cond_branch_taken);
                    assert(!ix_perf_cond_branch_not_taken);
                end

                5:
                begin
                    assert(ix_rollback_en);
                    assert(ix_rollback_pc == cr_eret_address[0]);
                    assert(ix_perf_uncond_branch);
                    assert(!ix_perf_cond_branch_taken);
                    assert(!ix_perf_cond_branch_not_taken);
                end

                ////////////////////////////////////////////////////////////
                // Test all other branch types
                ////////////////////////////////////////////////////////////
                10:
                begin
                    branch(BRANCH_REGISTER, BRANCH_ADDR0);
                    assert(!ix_perf_uncond_branch);
                    assert(!ix_perf_cond_branch_taken);
                    assert(!ix_perf_cond_branch_not_taken);
                end

                11:
                begin
                    assert(!ix_perf_uncond_branch);
                    assert(!ix_perf_cond_branch_taken);
                    assert(!ix_perf_cond_branch_not_taken);
                end

                12:
                begin
                    assert(ix_rollback_en);
                    assert(ix_rollback_pc == BRANCH_ADDR0);
                    assert(ix_perf_uncond_branch);
                    assert(!ix_perf_cond_branch_taken);
                    assert(!ix_perf_cond_branch_not_taken);

                    branch(BRANCH_ZERO, 0);
                end

                13:
                begin
                    assert(!ix_perf_uncond_branch);
                    assert(!ix_perf_cond_branch_taken);
                    assert(!ix_perf_cond_branch_not_taken);
                end

                14:
                begin
                    assert(ix_rollback_en);
                    assert(ix_rollback_pc == last_branch_pc + last_branch_offset);
                    assert(!ix_perf_uncond_branch);
                    assert(ix_perf_cond_branch_taken);
                    assert(!ix_perf_cond_branch_not_taken);

                    // will not be taken
                    branch(BRANCH_ZERO, 1);
                end

                15:
                begin
                    assert(!ix_perf_uncond_branch);
                    assert(!ix_perf_cond_branch_taken);
                    assert(!ix_perf_cond_branch_not_taken);
                end

                16:
                begin
                    // Ensure branch is not taken
                    assert(!ix_rollback_en);
                    assert(!ix_perf_uncond_branch);
                    assert(!ix_perf_cond_branch_taken);
                    assert(ix_perf_cond_branch_not_taken);
                    assert(ix_rollback_pc == last_branch_pc + last_branch_offset);

                    // Will be taken
                    branch(BRANCH_NOT_ZERO, 1);
                end

                17:
                begin
                    assert(!ix_perf_uncond_branch);
                    assert(!ix_perf_cond_branch_taken);
                    assert(!ix_perf_cond_branch_not_taken);
                end

                18:
                begin
                    assert(ix_rollback_en);
                    assert(!ix_perf_uncond_branch);
                    assert(ix_perf_cond_branch_taken);
                    assert(!ix_perf_cond_branch_not_taken);
                    assert(ix_rollback_pc == last_branch_pc + last_branch_offset);

                    // Will not be taken
                    branch(BRANCH_NOT_ZERO, 0);
                end

                19:
                begin
                    assert(!ix_perf_uncond_branch);
                    assert(!ix_perf_cond_branch_taken);
                    assert(!ix_perf_cond_branch_not_taken);
                end

                20:
                begin
                    // Ensure branch is not taken
                    assert(!ix_rollback_en);
                    assert(!ix_perf_uncond_branch);
                    assert(!ix_perf_cond_branch_taken);
                    assert(ix_perf_cond_branch_not_taken);

                    // register value should be ignored
                    branch(BRANCH_ALWAYS, 0);
                end

                21:
                begin
                    assert(!ix_perf_uncond_branch);
                    assert(!ix_perf_cond_branch_taken);
                    assert(!ix_perf_cond_branch_not_taken);
                end

                22:
                begin
                    assert(ix_rollback_en);
                    assert(ix_perf_uncond_branch);
                    assert(!ix_perf_cond_branch_taken);
                    assert(!ix_perf_cond_branch_not_taken);
                    assert(ix_rollback_pc == last_branch_pc + last_branch_offset);

                    // Try with opposite register value to ensure it's ignored
                    branch(BRANCH_ALWAYS, 1);
                end

                23:
                begin
                    assert(!ix_perf_uncond_branch);
                    assert(!ix_perf_cond_branch_taken);
                    assert(!ix_perf_cond_branch_not_taken);
                end

                24:
                begin
                    assert(ix_rollback_en);
                    assert(ix_perf_uncond_branch);
                    assert(!ix_perf_cond_branch_taken);
                    assert(!ix_perf_cond_branch_not_taken);
                    assert(ix_rollback_pc == last_branch_pc + last_branch_offset);

                    // Register value should be ignored
                    branch(BRANCH_CALL_OFFSET, 1);
                end

                25:
                begin
                    assert(!ix_perf_uncond_branch);
                    assert(!ix_perf_cond_branch_taken);
                    assert(!ix_perf_cond_branch_not_taken);
                end

                26:
                begin
                    assert(ix_rollback_en);
                    assert(ix_perf_uncond_branch);
                    assert(!ix_perf_cond_branch_taken);
                    assert(!ix_perf_cond_branch_not_taken);
                    assert(ix_rollback_pc == last_branch_pc + last_branch_offset);

                    // Try with other register value to ensure it is ignored
                    branch(BRANCH_CALL_OFFSET, 0);
                end

                27:
                begin
                    assert(!ix_perf_uncond_branch);
                    assert(!ix_perf_cond_branch_taken);
                    assert(!ix_perf_cond_branch_not_taken);
                end

                28:
                begin
                    assert(ix_rollback_en);
                    assert(ix_perf_uncond_branch);
                    assert(!ix_perf_cond_branch_taken);
                    assert(!ix_perf_cond_branch_not_taken);
                    assert(ix_rollback_pc == last_branch_pc + last_branch_offset);

                    branch(BRANCH_CALL_REGISTER, BRANCH_ADDR1);
                end

                29:
                begin
                    assert(!ix_perf_uncond_branch);
                    assert(!ix_perf_cond_branch_taken);
                    assert(!ix_perf_cond_branch_not_taken);
                end

                30:
                begin
                    assert(ix_rollback_en);
                    assert(ix_perf_uncond_branch);
                    assert(!ix_perf_cond_branch_taken);
                    assert(!ix_perf_cond_branch_not_taken);
                    assert(ix_rollback_pc == BRANCH_ADDR1);

                    // No branch this cycle...
                end

                31:
                begin
                    assert(!ix_rollback_en);
                    assert(!ix_perf_uncond_branch);
                    assert(!ix_perf_cond_branch_taken);
                    assert(!ix_perf_cond_branch_not_taken);
                end

                32:
                begin
                    $display("PASS");
                    $finish;
                end
            endcase
        end
    end
endmodule
