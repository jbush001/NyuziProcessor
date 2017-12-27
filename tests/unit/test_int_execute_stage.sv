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

`include "defines.sv"

import defines::*;

module test_int_execute_stage(input clk, input reset);
    localparam ERET_ADDR = 'h12340020;

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

    int_execute_stage int_execute_stage(.*);

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
                // Eret from user mode
                0:
                begin
                    of_instruction_valid <= 1;
                    of_instruction.branch <= 1;
                    of_instruction.branch_type <= BRANCH_ERET;
                    cr_supervisor_en[0] <= 0;
                    of_instruction.pipeline_sel <= PIPE_INT_ARITH;
                end
                // wait cycle

                2:  assert(ix_privileged_op_fault);

                // Eret from supervisor mode (okay)
                3:
                begin
                    of_instruction_valid <= 1;
                    of_instruction.branch <= 1;
                    of_instruction.branch_type <= BRANCH_ERET;
                    cr_supervisor_en[0] <= 1;
                    cr_eret_address[0] <= ERET_ADDR;
                    cr_eret_address[1] <= $random();
                    cr_eret_address[2] <= $random();
                    cr_eret_address[3] <= $random();
                    of_instruction.pipeline_sel <= PIPE_INT_ARITH;
                end
                // wait cycle

                5:
                begin
                    assert(ix_rollback_en);
                    assert(ix_rollback_pc == cr_eret_address[0]);
                end

                6:
                begin
                    $display("PASS");
                    $finish;
                end
            endcase
        end
    end
endmodule
