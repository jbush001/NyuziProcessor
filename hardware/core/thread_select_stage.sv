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
// Instruction Pipeline Thread Select Stage
// - Contains an instruction FIFO for each thread
// - Each cycle, picks a thread to issue using a round robin scheduling
//   algorithm, avoiding various types of conflicts:
//   * inter-instruction register dependencies (read-after-write,
//     write-after-write, write-after-read), tracked using a scoreboard for
//     each thread.
//   * writeback hazards between the pipelines of different lengths, tracked
//     with a shared shift register.
// - Tracks dcache misses and suspends threads until they are resolved.
//

module thread_select_stage(
    input                              clk,
    input                              reset,

    // From instruction_decode_stage
    input decoded_instruction_t        id_instruction,
    input                              id_instruction_valid,
    input local_thread_idx_t           id_thread_idx,

    // To ifetch_tag_stage
    output local_thread_bitmap_t       ts_fetch_en,

    // To operand_fetch_stage
    output logic                       ts_instruction_valid,
    output decoded_instruction_t       ts_instruction,
    output local_thread_idx_t          ts_thread_idx,
    output subcycle_t                  ts_subcycle,

    // From writeback_stage
    input                              wb_writeback_en,
    input local_thread_idx_t           wb_writeback_thread_idx,
    input                              wb_writeback_is_vector,
    input register_idx_t               wb_writeback_reg,
    input                              wb_writeback_is_last_subcycle,
    input local_thread_idx_t           wb_rollback_thread_idx,
    input                              wb_rollback_en,
    input pipeline_sel_t               wb_rollback_pipeline,
    input subcycle_t                   wb_rollback_subcycle,

    // From interrupt_controller
    input local_thread_bitmap_t        thread_en,

    // From dcache_data_stage
    input local_thread_bitmap_t        wb_suspend_thread_oh,
    input local_thread_bitmap_t        l2i_dcache_wake_bitmap,
    input local_thread_bitmap_t        ior_wake_bitmap,

    // To performance_counters
    output logic                       ts_perf_instruction_issue);

    localparam THREAD_FIFO_SIZE = 8;

    // Number of stages in longest pipeline
    localparam ROLLBACK_STAGES = 4;

    // Difference between longest and shortest execution pipeline
    localparam WRITEBACK_ALLOC_STAGES = 4;

    localparam SCOREBOARD_ENTRIES = NUM_REGISTERS * 2;

    decoded_instruction_t thread_instr[`THREADS_PER_CORE];
    decoded_instruction_t issue_instr;
    local_thread_bitmap_t thread_blocked;
    local_thread_bitmap_t can_issue_thread;
    local_thread_bitmap_t thread_issue_oh;
    local_thread_idx_t issue_thread_idx;
    logic[WRITEBACK_ALLOC_STAGES - 1:0] writeback_allocate;
    logic[WRITEBACK_ALLOC_STAGES - 1:0] writeback_allocate_nxt;
    subcycle_t current_subcycle[`THREADS_PER_CORE];
    logic issue_last_subcycle[`THREADS_PER_CORE];

    // The scoreboard tracks registers that are busy (have a result pending), with one bit
    // per register. Bits 0-31 are scalar registers and 32-63 are vector registers.
    logic[SCOREBOARD_ENTRIES - 1:0] scoreboard[`THREADS_PER_CORE];
    logic[SCOREBOARD_ENTRIES - 1:0] scoreboard_nxt[`THREADS_PER_CORE];
    logic[SCOREBOARD_ENTRIES - 1:0] scoreboard_dest_bitmap[`THREADS_PER_CORE];

    // Track issued instructions so we can clear scoreboard entries on a rollback
    struct packed {
        logic valid;
        local_thread_idx_t thread_idx;
        logic[SCOREBOARD_ENTRIES - 1:0] scoreboard_bitmap;
    } rollback_dest[ROLLBACK_STAGES];

`ifdef SIMULATION
    // Used for visualizer app
    enum logic[2:0] {
        TS_WAIT_ICACHE = 0,
        TS_WAIT_DCACHE = 1,
        TS_WAIT_RAW = 2,
        TS_WAIT_WRITEBACK_CONFLICT = 3,
        TS_READY = 4
    } thread_state[`THREADS_PER_CORE];
`endif

    //
    // Per-thread instruction FIFOs & scoreboards
    //
    genvar thread_idx;
    generate
        for (thread_idx = 0; thread_idx < `THREADS_PER_CORE; thread_idx++)
        begin : thread_logic_gen
            logic ififo_almost_full;
            logic ififo_empty;
            logic[SCOREBOARD_ENTRIES - 1:0] scoreboard_clear_bitmap;
            logic[SCOREBOARD_ENTRIES - 1:0] scoreboard_set_bitmap;
            logic[SCOREBOARD_ENTRIES - 1:0] scoreboard_dep_bitmap;
            logic[SCOREBOARD_ENTRIES - 1:0] scoreboard_dep_bitmap_nxt;
            logic[SCOREBOARD_ENTRIES - 1:0] scoreboard_dest_bitmap_nxt;
            decoded_instruction_t thread_instr_nxt;
            logic instruction_latched;
            logic writeback_conflict;
            logic rollback_this_thread;
            logic enqueue_this_thread;
            logic instruction_latch_en;
            logic scoreboard_conflict;

            assign rollback_this_thread = wb_rollback_en
                && wb_rollback_thread_idx == local_thread_idx_t'(thread_idx);
            assign enqueue_this_thread = id_instruction_valid
                && id_thread_idx == local_thread_idx_t'(thread_idx);

            sync_fifo #(
                .WIDTH($bits(id_instruction)),
                .SIZE(THREAD_FIFO_SIZE),
                .ALMOST_FULL_THRESHOLD(THREAD_FIFO_SIZE - 3)
            ) instruction_fifo(
                .flush_en(rollback_this_thread),
                .full(),
                .almost_full(ififo_almost_full),
                .enqueue_en(enqueue_this_thread),
                .value_i(id_instruction),
                .empty(ififo_empty),
                .almost_empty(),
                .dequeue_en(instruction_latch_en),
                .value_o(thread_instr_nxt),
                .*);

            assign issue_last_subcycle[thread_idx] = thread_issue_oh[thread_idx]
                && current_subcycle[thread_idx] == thread_instr[thread_idx].last_subcycle;

            // This signal goes back to the ifetch_tag_stage to enable fetching more
            // instructions. Deassert fetch enable a few cycles before the FIFO
            // fills up because there are several stages in-between.
            assign ts_fetch_en[thread_idx] = !ififo_almost_full && thread_en[thread_idx];

            // Generate destination register bitmap for the next instruction
            // to be issued.
            always_comb
            begin
                scoreboard_dest_bitmap_nxt = 0;
                if (thread_instr_nxt.has_dest)
                begin
                    if (thread_instr_nxt.dest_is_vector)
                        scoreboard_dest_bitmap_nxt[{1'b1, thread_instr_nxt.dest_reg}] = 1;
                    else
                        scoreboard_dest_bitmap_nxt[{1'b0, thread_instr_nxt.dest_reg}] = 1;
                end
            end

            // Generate register dependency bitmap for next instruction this thread
            // will issue. This includes source registers (to detect RAW dependencies)
            // and the destination register (to handle WAW and WAR dependencies)
            always_comb
            begin
                scoreboard_dep_bitmap_nxt = 0;
                if (thread_instr_nxt.has_dest)
                begin
                    if (thread_instr_nxt.dest_is_vector)
                        scoreboard_dep_bitmap_nxt[{1'b1, thread_instr_nxt.dest_reg}] = 1;
                    else
                        scoreboard_dep_bitmap_nxt[{1'b0, thread_instr_nxt.dest_reg}] = 1;
                end

                if (thread_instr_nxt.has_scalar1)
                    scoreboard_dep_bitmap_nxt[{1'b0, thread_instr_nxt.scalar_sel1}] = 1;

                if (thread_instr_nxt.has_scalar2)
                    scoreboard_dep_bitmap_nxt[{1'b0, thread_instr_nxt.scalar_sel2}] = 1;

                if (thread_instr_nxt.has_vector1)
                    scoreboard_dep_bitmap_nxt[{1'b1, thread_instr_nxt.vector_sel1}] = 1;

                if (thread_instr_nxt.has_vector2)
                    scoreboard_dep_bitmap_nxt[{1'b1, thread_instr_nxt.vector_sel2}] = 1;
            end

            // There is one cycle of latency after the instruction comes out of the
            // instruction FIFO to determine the scoreboard values. Registered them
            // here.
            assign instruction_latch_en = !ififo_empty && (!instruction_latched
                || issue_last_subcycle[thread_idx]);

            always_ff @(posedge clk)
            begin
                if (instruction_latch_en)
                    thread_instr[thread_idx] <= thread_instr_nxt;
            end

            always_ff @(posedge clk, posedge reset)
            begin
                if (reset)
                begin
                    instruction_latched <= 0;
                    scoreboard_dep_bitmap <= 0;
                    scoreboard_dest_bitmap[thread_idx] <= 0;
                end
                else
                begin
                    if (rollback_this_thread)
                        instruction_latched <= 0;
                    else if (instruction_latch_en)
                    begin
                        // Latch a new instruction
                        instruction_latched <= 1;
                        scoreboard_dep_bitmap <= scoreboard_dep_bitmap_nxt;
                        scoreboard_dest_bitmap[thread_idx] <= scoreboard_dest_bitmap_nxt;
                    end
                    else if (issue_last_subcycle[thread_idx])
                        instruction_latched <= 0;    // Clear instruction
                end
            end

            // Determine which scoreboard bits to clear
            always_comb
            begin
                // Clear scoreboard entries for completed instructions.
                // Only do this on the last subcycle of an instruction.
                // Since this doesn't wait on the scoreboard to issue
                // intermediate subcycles, this is necessary for correctness.
                scoreboard_clear_bitmap = 0;
                if (wb_writeback_en && wb_writeback_thread_idx == local_thread_idx_t'(thread_idx)
                    && wb_writeback_is_last_subcycle)
                begin
                    if (wb_writeback_is_vector)
                        scoreboard_clear_bitmap[{1'b1, wb_writeback_reg}] = 1;
                    else
                        scoreboard_clear_bitmap[{1'b0, wb_writeback_reg}] = 1;
                end

                // Clear scoreboard entries for rolled back threads.
                if (wb_rollback_en && wb_rollback_thread_idx == local_thread_idx_t'(thread_idx))
                begin
                    for (int i = 0; i < ROLLBACK_STAGES - 1; i++)
                    begin
                        if (rollback_dest[i].valid && rollback_dest[i].thread_idx == local_thread_idx_t'(thread_idx))
                            scoreboard_clear_bitmap |= rollback_dest[i].scoreboard_bitmap;
                    end

                    // The memory pipeline is one stage longer than the integer
                    // arithmetic pipeline, so only invalidate the last stage
                    // if this originated there.
                    if (rollback_dest[ROLLBACK_STAGES - 1].valid
                        && rollback_dest[ROLLBACK_STAGES - 1].thread_idx
                        == local_thread_idx_t'(thread_idx)
                        && wb_rollback_pipeline == PIPE_MEM)
                    begin
                        scoreboard_clear_bitmap |= rollback_dest[ROLLBACK_STAGES - 1]
                            .scoreboard_bitmap;
                    end
                end
            end

            always_comb
            begin
                // There can be a writeback conflict even if the instruction doesn't
                // write back to a register (if it cause a rollback, for example)
                case (thread_instr[thread_idx].pipeline_sel)
                    PIPE_INT_ARITH: writeback_conflict = writeback_allocate[0];
                    PIPE_MEM: writeback_conflict = writeback_allocate[1];
                    default: writeback_conflict = 0;
                endcase
            end

            // Only check the scoreboard on the first subcycle. The scoreboard only
            // tracks register granularity, not individual vector lanes. In most
            // cases, this is fine, but with a multi-cycle operation (like a gather
            // load), which writes back to the same register multiple times, this
            // would delay the load.
            assign scoreboard_conflict = (scoreboard[thread_idx]
                & scoreboard_dep_bitmap) != 0 && current_subcycle[thread_idx] == 0;
            assign can_issue_thread[thread_idx] = instruction_latched
                && !scoreboard_conflict
                && thread_en[thread_idx]
                && !rollback_this_thread
                && !writeback_conflict
                && !thread_blocked[thread_idx];

            // Update scoreboard.
            assign scoreboard_set_bitmap = scoreboard_dest_bitmap[thread_idx]
                & {SCOREBOARD_ENTRIES{thread_issue_oh[thread_idx]}};
            assign scoreboard_nxt[thread_idx] =
                (scoreboard[thread_idx] & ~scoreboard_clear_bitmap)
                | scoreboard_set_bitmap;

            always_ff @(posedge clk, posedge reset)
            begin
                if (reset)
                begin
                    scoreboard[thread_idx] <= 0;
                    current_subcycle[thread_idx] <= 0;
                end
                else
                begin
                    scoreboard[thread_idx] <= scoreboard_nxt[thread_idx];
                    if (wb_rollback_en && wb_rollback_thread_idx == local_thread_idx_t'(thread_idx))
                        current_subcycle[thread_idx] <= wb_rollback_subcycle;
                    else if (issue_last_subcycle[thread_idx])
                        current_subcycle[thread_idx] <= 0;
                    else if (thread_issue_oh[thread_idx])
                        current_subcycle[thread_idx] <= current_subcycle[thread_idx] + subcycle_t'(1);
                end
            end

`ifdef SIMULATION
            // Used for visualizer tool. There can be multiple events that prevent
            // a thread from executing, but I picked a order that seemed logical
            // to prioritize them so there is only one "state."
            always_comb
            begin
                if (!instruction_latched)
                    thread_state[thread_idx] = TS_WAIT_ICACHE;
                else if (thread_blocked[thread_idx])
                    thread_state[thread_idx] = TS_WAIT_DCACHE;
                else if (!can_issue_thread[thread_idx])
                    thread_state[thread_idx] = TS_WAIT_RAW;
                else if (writeback_conflict)
                    thread_state[thread_idx] = TS_WAIT_WRITEBACK_CONFLICT;
                else
                    thread_state[thread_idx] = TS_READY;
            end
`endif
        end
    endgenerate

    // At the writeback stage, the floating point, integer, and memory
    // pipelines merge. Since these have different lengths, there is
    // a structural hazard where two instructions issued in different
    // cycles could arrive during the same cycle. Avoid that by tracking
    // instruction issue and not scheduling instructions that would
    // collide. Track instructions even if they don't write back to a
    // register, since they may have other side effects that the writeback
    // stage handles (for example, a store instruction can raise an exception)
    always_comb
    begin
        writeback_allocate_nxt = {1'b0, writeback_allocate[WRITEBACK_ALLOC_STAGES - 1:1]};
        if (|thread_issue_oh)
        begin
            case (issue_instr.pipeline_sel)
                PIPE_FLOAT_ARITH: writeback_allocate_nxt[3] = 1'b1;
                PIPE_MEM: writeback_allocate_nxt[0] = 1'b1;
                default:
                    ;
            endcase
        end
    end

    //
    // Choose which thread to issue
    //
    rr_arbiter #(.NUM_REQUESTERS(`THREADS_PER_CORE)) thread_select_arbiter(
        .request(can_issue_thread),
        .update_lru(1'b1),
        .grant_oh(thread_issue_oh),
        .*);

    oh_to_idx #(.NUM_SIGNALS(`THREADS_PER_CORE)) thread_oh_to_idx(
        .one_hot(thread_issue_oh),
        .index(issue_thread_idx));

    assign issue_instr = thread_instr[issue_thread_idx];
    assign ts_perf_instruction_issue = |thread_issue_oh;

    always_ff @(posedge clk)
    begin
        ts_instruction <= issue_instr;
        ts_thread_idx <= issue_thread_idx;
        ts_subcycle <= current_subcycle[issue_thread_idx];
    end

    always_ff @(posedge clk, posedge reset)
    begin
        if (reset)
        begin
            for (int i = 0; i < ROLLBACK_STAGES; i++)
                rollback_dest[i] <= 0;

            `ifdef NEVER
            // Suppress autoreset
            scoreboard_bitmap <= '0;
            valid <= 0;
            thread_idx <= '0;
            `endif

            /*AUTORESET*/
            // Beginning of autoreset for uninitialized flops
            thread_blocked <= '0;
            ts_instruction_valid <= '0;
            writeback_allocate <= '0;
            // End of automatics
        end
        else
        begin
            // Should not get a wake from l1 cache and io queue in the same cycle
            assert((l2i_dcache_wake_bitmap & ior_wake_bitmap) == 0);

            // Check for suspending a thread that isn't running
            assert((wb_suspend_thread_oh & thread_blocked) == 0);

            // Check for waking a thread that isn't suspended (or about to be suspended, see note below)
            assert(((l2i_dcache_wake_bitmap | ior_wake_bitmap) & ~(thread_blocked | wb_suspend_thread_oh)) == 0);

            // Don't issue blocked threads
            assert((thread_issue_oh & thread_blocked) == 0);

            // Only one thread should be blocked per cycle
            assert($onehot0(wb_suspend_thread_oh));

            ts_instruction_valid <= |thread_issue_oh;

            // The writeback stage asserts the suspend signal a cycle after a dcache
            // miss occurs. It is possible a cache miss is already pending for that
            // address, and that it gets filled in the next cycle. In this case,
            // suspend and wake will be asserted simultaneously. Wake will win
            // because of the order of this expression. This is intended, since
            // cache data is now available and the thread won't be rolled back.
            thread_blocked <= (thread_blocked | wb_suspend_thread_oh)
                & ~(l2i_dcache_wake_bitmap | ior_wake_bitmap);

            // Track issued instructions for scoreboard clearing
            for (int i = 1; i < ROLLBACK_STAGES; i++)
            begin
                if (rollback_dest[i - 1].thread_idx == wb_rollback_thread_idx && wb_rollback_en)
                    rollback_dest[i] <= 0;    // Clear rolled back instruction
                else
                    rollback_dest[i] <= rollback_dest[i - 1]; // Shift down pipeline
            end

            rollback_dest[0].valid <= |thread_issue_oh && issue_instr.has_dest;
            rollback_dest[0].thread_idx <= issue_thread_idx;
            rollback_dest[0].scoreboard_bitmap <= scoreboard_dest_bitmap[issue_thread_idx];

            writeback_allocate <= writeback_allocate_nxt;
        end
    end
endmodule
