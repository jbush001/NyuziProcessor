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

module test_scoreboard(input clk, input reset);
    decoded_instruction_t next_instruction;
    int cycle;
    logic scoreboard_can_issue;
    logic will_issue;
    logic writeback_en;
    logic wb_writeback_vector;
    register_idx_t wb_writeback_reg;
    logic rollback_en;
    pipeline_sel_t wb_rollback_pipeline;

    scoreboard scoreboard(.*);

    task enqueue_ss(input register_idx_t dest, input register_idx_t src1,
            input register_idx_t src2);
        next_instruction.has_dest <= 1;
        next_instruction.dest_vector <= 0;
        next_instruction.dest_reg <= dest;
        next_instruction.has_scalar1 <= 1;
        next_instruction.scalar_sel1 <= src1;
        next_instruction.has_scalar2 <= 1;
        next_instruction.scalar_sel2 <= src2;
    endtask

    task enqueue_vv(input register_idx_t dest, input register_idx_t src1,
            input register_idx_t src2);
        next_instruction.has_dest <= 1;
        next_instruction.dest_vector <= 1;
        next_instruction.dest_reg <= dest;
        next_instruction.has_vector1 <= 1;
        next_instruction.vector_sel1 <= src1;
        next_instruction.has_vector2 <= 1;
        next_instruction.vector_sel2 <= src2;
    endtask

    task enqueue_store(input register_idx_t src1,
            input register_idx_t src2);
        next_instruction.has_scalar1 <= 1;
        next_instruction.scalar_sel1 <= src1;
        next_instruction.has_scalar2 <= 1;
        next_instruction.scalar_sel2 <= src2;
    endtask

    // Register 25 is used below as a register that should never be pending.
    always @(posedge clk, posedge reset)
    begin
        if (reset)
            cycle <= 0;
        else
        begin
            // By default, clear all instruction fields
            next_instruction <= '0;
            will_issue <= 0;
            writeback_en <= 0;
            rollback_en <= 0;

            cycle <= cycle + 1;
            unique0 case (cycle)
                // Test setting and clearing scoreboard bits during instruction
                // issue/retire
                0:
                begin
                    // Scalar register 1 is marked pending
                    enqueue_ss(1, 2, 2);
                    will_issue <= 1;
                end

                1:
                begin
                    assert(scoreboard_can_issue);

                    // Vector register 2 is marked pending
                    enqueue_vv(2, 25, 25);
                    will_issue <= 1;
                end

                2:
                begin
                    assert(scoreboard_can_issue);

                    // Scalar source 1 is pending and can't issue
                    // (note: this doesn't issue and update the scoreboard, because
                    // will_issue is not set, we just check to see if it can issue).
                    enqueue_ss(25, 1, 25);
                end

                3:
                begin
                    assert(!scoreboard_can_issue);

                    // Scalar source 2 is pending
                    enqueue_ss(25, 25, 1);
                end

                4:
                begin
                    assert(!scoreboard_can_issue);

                    // Vector source 1 is pending
                    enqueue_vv(25, 2, 25);
                end

                5:
                begin
                    assert(!scoreboard_can_issue);

                    // Vector source 2 is pending
                    enqueue_vv(25, 25, 2);
                end

                6:
                begin
                    assert(!scoreboard_can_issue);

                    // The vector register index (2) is pending, but not the scalar.
                    // This checks that the logic is differentiating between vector
                    // and scalar registers. This should be able to issue.
                    enqueue_ss(25, 2, 2);
                end

                7:
                begin
                    assert(scoreboard_can_issue);
                    enqueue_vv(25, 1, 1);
                end

                8:
                begin
                    assert(scoreboard_can_issue);

                    // Retire the scalar register to clear the bit.
                    writeback_en <= 1;
                    wb_writeback_reg <= 1;
                    wb_writeback_vector <= 0;
                end

                // Check if we can now issue the scalar instruction (should be
                // able to now that the bit is clear).
                9:  enqueue_ss(25, 1, 1);

                10:
                begin
                    assert(scoreboard_can_issue);

                    // Retire the vector register
                    writeback_en <= 1;
                    wb_writeback_reg <= 2;
                    wb_writeback_vector <= 1;
                end

                // Check if we can now issue the vector instruction
                11:  enqueue_ss(25, 2, 2);
                12:
                begin
                    assert(scoreboard_can_issue);

                    // Issue a sequence of instructions that we're going to
                    // roll back.
                    enqueue_ss(4, 25, 25);
                    will_issue <= 1;
                end

                13:
                begin
                    assert(scoreboard_can_issue);
                    enqueue_ss(5, 25, 25);
                    will_issue <= 1;
                end

                14:
                begin
                    assert(scoreboard_can_issue);
                    enqueue_vv(6, 25, 25);
                    will_issue <= 1;
                end

                15:
                begin
                    assert(scoreboard_can_issue);
                    enqueue_vv(7, 25, 25);
                    will_issue <= 1;
                end

                16:
                begin
                    assert(scoreboard_can_issue);

                    // Rollback from the integer stage, which should clear
                    // *three* of the registers above, but leave the first issued
                    // pending.
                    rollback_en <= 1;
                    wb_rollback_pipeline <= PIPE_INT_ARITH;
                end

                17: enqueue_ss(25, 5, 5);

                18:
                begin
                    // Verify this register doesn't have a conflict (reg 4 does)
                    assert(scoreboard_can_issue);

                    // Neither of these should cause a conflict
                    enqueue_vv(25, 7, 8);
                end

                19:
                begin
                    assert(scoreboard_can_issue);

                    // But this one will not be able to issue, because 4 wasn't rolled back.
                    enqueue_ss(25, 4, 25);
                end

                20:
                begin
                    assert(!scoreboard_can_issue);

                    // Issue four more instructions, for which we will do a memory
                    // rollback.
                    enqueue_vv(8, 25, 25);
                    will_issue <= 1;
                end

                21:
                begin
                    assert(scoreboard_can_issue);
                    enqueue_vv(9, 25, 25);
                    will_issue <= 1;
                end

                22:
                begin
                    assert(scoreboard_can_issue);
                    enqueue_ss(10, 25, 25);
                    will_issue <= 1;
                end

                23:
                begin
                    assert(scoreboard_can_issue);
                    enqueue_ss(11, 25, 25);
                    will_issue <= 1;
                end

                24:
                begin
                    assert(scoreboard_can_issue);
                    rollback_en <= 1;
                    wb_rollback_pipeline <= PIPE_MEM;
                end

                // Check that the bits are cleared
                25: enqueue_vv(25, 8, 9);

                26:
                begin
                    assert(scoreboard_can_issue);
                    enqueue_ss(25, 10, 11);
                end

                27:
                begin
                    assert(scoreboard_can_issue);

                    // Test an instruction that doesn't have a destination specified
                    enqueue_store(25, 25);
                    will_issue <= 1;
                end

                28:
                begin
                    assert(scoreboard_can_issue);

                    // The destination register in the instruction above defaulted
                    // to zero. Ensure this is not busy.
                    enqueue_ss(25, 0, 0);
                end

                29:
                begin
                    assert(scoreboard_can_issue);

                    // Set register 13 to busy, then check for a WAW conflict
                    enqueue_ss(13, 25, 25);
                    will_issue <= 1;
                end

                30:
                begin
                    assert(scoreboard_can_issue);

                    // Because this uses register 13 as a *destination*, it should
                    // conflict.
                    enqueue_ss(13, 25, 25);
                end

                31: assert(!scoreboard_can_issue);

                // Ensure registers are properly shifted through the rollback pipeline.
                // We'll issue one instruction that marks a register pending, wait four
                // cycles, then rollback. This should not be cleared when the rollback
                // occurs (this simulates an instruction moving through the floating point
                // pipeline). There was a bug with this in the first implementation of
                // the scoreboard.
                32:
                begin
                    enqueue_ss(14, 25, 25);
                    will_issue <= 1;
                end

                33: assert(scoreboard_can_issue);

                // Skip 34-37

                38:
                begin
                    // The rollback should *not* clear 14, because it is no longer in
                    // the pipeline
                    rollback_en <= 1;
                    wb_rollback_pipeline <= PIPE_MEM;
                end

                39:
                begin
                    // This instruction uses the dest register as a source.
                    enqueue_ss(25, 14, 14);
                end

                40:
                begin
                    // ...this should not issue
                    assert(!scoreboard_can_issue);
                end

                41:
                begin
                    $display("PASS");
                    $finish;
                end
            endcase
        end
    end
endmodule
