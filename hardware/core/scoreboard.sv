//
// Copyright 2011-2017 Jeff Bush
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
// The scoreboard tracks register dependencies betwen instructions
// issued by the same thread. For example, if a thread issued the
// following instructions in sequence:
//
//   add_i s0, s1, s2
//   add_i s3, s0, s4
//
// The second instruction has a read-after-write (RAW) dependency on s0.
// It cannot be issued until the first instruction completes.
// This works by keeping a bitmap for all registers and marking the destination
// for each instruction as 'busy' when it is issued. When checking if the next
// instruction can be issued, it looks at the source registers and halts
// if the busy bit is set for any of them.
//

module scoreboard(
    input                           clk,
    input                           reset,
    input decoded_instruction_t     next_instruction,
    output logic                    scoreboard_can_issue,
    input                           will_issue,
    input                           writeback_en,
    input                           wb_writeback_vector,
    input register_idx_t            wb_writeback_reg,
    input                           rollback_en,
    input pipeline_sel_t            wb_rollback_pipeline);

    localparam SCOREBOARD_ENTRIES = NUM_REGISTERS * 2;

    // This represents the longest path between the thread select and
    // writeback stages:
    // operand_fetch -> dcache_tag -> dcache_data -> writeback
    // It does not include the floating point pipeline, as that does not
    // generate traps.
    localparam ROLLBACK_STAGES = 4;

    typedef logic[SCOREBOARD_ENTRIES - 1:0] scoreboard_bitmap_t;
    typedef logic[5:0] ext_register_idx_t;  // 0-31 are scalar, 32-63 vector

    logic[ROLLBACK_STAGES - 1:0] has_writeback;
    ext_register_idx_t writeback_reg[ROLLBACK_STAGES];
    scoreboard_bitmap_t scoreboard_regs;
    scoreboard_bitmap_t scoreboard_regs_nxt;
    scoreboard_bitmap_t dest_bitmap;
    scoreboard_bitmap_t dep_bitmap;
    scoreboard_bitmap_t rollback_bitmap;
    scoreboard_bitmap_t writeback_bitmap;
    scoreboard_bitmap_t clear_bitmap;
    scoreboard_bitmap_t set_bitmap;

    // Handle rollback for a thread (for example, if it takes a branch)
    // Why not just clear the entire scoreboard?
    // - Instructions in the floating point pipeline *after* the stage that
    //   issues the rollback should still retire (thus their destinations
    //   are still pending).
    // - Likewise for memory instructions when the integer pipeline causes
    //   a rollback.
    always_comb
    begin
        rollback_bitmap = 0;
        if (rollback_en)
        begin
            for (int i = 0; i < ROLLBACK_STAGES - 1; i++)
                if (has_writeback[i])
                    rollback_bitmap[writeback_reg[i]] = 1;

            // The memory pipeline is one stage longer than the integer
            // pipeline, so include that stage if it generated the rollback.
            if (has_writeback[ROLLBACK_STAGES - 1]
                && wb_rollback_pipeline == PIPE_MEM)
                rollback_bitmap[writeback_reg[ROLLBACK_STAGES - 1]] = 1;
        end
    end

    // Dependencies
    always_comb
    begin
        dep_bitmap = 0;
        if (next_instruction.has_dest)
        begin
            if (next_instruction.dest_vector)
                dep_bitmap[{1'b1, next_instruction.dest_reg}] = 1;
            else
                dep_bitmap[{1'b0, next_instruction.dest_reg}] = 1;
        end

        if (next_instruction.has_scalar1)
            dep_bitmap[{1'b0, next_instruction.scalar_sel1}] = 1;

        if (next_instruction.has_scalar2)
            dep_bitmap[{1'b0, next_instruction.scalar_sel2}] = 1;

        if (next_instruction.has_vector1)
            dep_bitmap[{1'b1, next_instruction.vector_sel1}] = 1;

        if (next_instruction.has_vector2)
            dep_bitmap[{1'b1, next_instruction.vector_sel2}] = 1;
    end

    // Destination
    always_comb
    begin
        dest_bitmap = 0;
        if (next_instruction.has_dest)
        begin
            if (next_instruction.dest_vector)
                dest_bitmap[{1'b1, next_instruction.dest_reg}] = 1;
            else
                dest_bitmap[{1'b0, next_instruction.dest_reg}] = 1;
        end
    end

    // Registers to clear when a writeback occurs
    always_comb
    begin
        writeback_bitmap = 0;
        if (writeback_en)
        begin
            if (wb_writeback_vector)
                writeback_bitmap[{1'b1, wb_writeback_reg}] = 1;
            else
                writeback_bitmap[{1'b0, wb_writeback_reg}] = 1;
        end
    end

    assign clear_bitmap = rollback_bitmap | writeback_bitmap;
    assign set_bitmap = dest_bitmap
        & {SCOREBOARD_ENTRIES{will_issue}};
    assign scoreboard_regs_nxt = (scoreboard_regs & ~clear_bitmap)
        | set_bitmap;
    assign scoreboard_can_issue = (scoreboard_regs & dep_bitmap) == 0;

    always @(posedge clk, posedge reset)
    begin
        if (reset)
        begin
            scoreboard_regs <= '0;
            has_writeback <= '0;
        end
        else
        begin
            scoreboard_regs <= scoreboard_regs_nxt;
            has_writeback <= {has_writeback[ROLLBACK_STAGES - 2:0],
                will_issue && next_instruction.has_dest};
        end
    end

    always @(posedge clk)
    begin
        if (will_issue)
            writeback_reg[0] <= {next_instruction.dest_vector, next_instruction.dest_reg};

        for (int i = 1; i < ROLLBACK_STAGES; i++)
            writeback_reg[i] <= writeback_reg[i - 1];
    end
endmodule
