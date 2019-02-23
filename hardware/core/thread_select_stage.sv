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
    input                              wb_writeback_vector,
    input register_idx_t               wb_writeback_reg,
    input                              wb_writeback_last_subcycle,
    input local_thread_idx_t           wb_rollback_thread_idx,
    input                              wb_rollback_en,
    input pipeline_sel_t               wb_rollback_pipeline,
    input subcycle_t                   wb_rollback_subcycle,

    // From nyuzi
    input local_thread_bitmap_t        thread_en,

    // From dcache_data_stage
    input local_thread_bitmap_t        wb_suspend_thread_oh,
    input local_thread_bitmap_t        l2i_dcache_wake_bitmap,
    input local_thread_bitmap_t        ior_wake_bitmap,

    // To performance_counters
    output logic                       ts_perf_instruction_issue);

    localparam THREAD_FIFO_SIZE = 8;

    // Difference between longest and shortest execution pipeline
    localparam WRITEBACK_ALLOC_STAGES = 4;

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
            logic writeback_conflict;
            logic rollback_this_thread;
            logic enqueue_this_thread;
            logic writeback_this_thread;
            logic scoreboard_can_issue;

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
                .enqueue_value(id_instruction),
                .empty(ififo_empty),
                .almost_empty(),
                .dequeue_en(issue_last_subcycle[thread_idx]),
                .dequeue_value(thread_instr[thread_idx]),
                .*);

            assign writeback_this_thread = wb_writeback_en
                && wb_writeback_thread_idx == local_thread_idx_t'(thread_idx)
                && wb_writeback_last_subcycle;
            assign rollback_this_thread = wb_rollback_en
                && wb_rollback_thread_idx == local_thread_idx_t'(thread_idx);

            scoreboard scoreboard(
                .next_instruction(thread_instr[thread_idx]),
                .will_issue(thread_issue_oh[thread_idx]),
                .writeback_en(writeback_this_thread),
                .rollback_en(rollback_this_thread),
                .*);

            // This signal goes back to the ifetch_tag_stage to enable fetching more
            // instructions. Deassert fetch enable a few cycles before the FIFO
            // fills up because there are several stages in-between.
            assign ts_fetch_en[thread_idx] = !ififo_almost_full && thread_en[thread_idx];

            always_comb
            begin
                // There can be a writeback conflict even if the instruction doesn't
                // write back to a register (if it cause a rollback, for example)
                unique case (thread_instr[thread_idx].pipeline_sel)
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
            assign can_issue_thread[thread_idx] = !ififo_empty
                && (scoreboard_can_issue || current_subcycle[thread_idx] != 0)
                && thread_en[thread_idx]
                && !rollback_this_thread
                && !writeback_conflict
                && !thread_blocked[thread_idx];
            assign issue_last_subcycle[thread_idx] = thread_issue_oh[thread_idx]
                && current_subcycle[thread_idx] == thread_instr[thread_idx].last_subcycle;

            always_ff @(posedge clk, posedge reset)
            begin
                if (reset)
                    current_subcycle[thread_idx] <= 0;
                else if (wb_rollback_en && wb_rollback_thread_idx == local_thread_idx_t'(thread_idx))
                    current_subcycle[thread_idx] <= wb_rollback_subcycle;
                else if (issue_last_subcycle[thread_idx])
                    current_subcycle[thread_idx] <= 0;
                else if (thread_issue_oh[thread_idx])
                    current_subcycle[thread_idx] <= current_subcycle[thread_idx] + subcycle_t'(1);
            end

`ifdef SIMULATION
            // Used for visualizer tool. There can be multiple events that prevent
            // a thread from executing, but I picked a order that seemed logical
            // to prioritize them so there is only one "state."
            // XXX does not capture rollbacks.
            always_comb
            begin
                if (ififo_empty)
                    thread_state[thread_idx] = TS_WAIT_ICACHE;
                else if (thread_blocked[thread_idx])
                    thread_state[thread_idx] = TS_WAIT_DCACHE;
                else if (!scoreboard_can_issue && current_subcycle[thread_idx] == 0)
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
            unique case (issue_instr.pipeline_sel)
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
            /*AUTORESET*/
            // Beginning of autoreset for uninitialized flops
            thread_blocked <= '0;
            ts_instruction_valid <= '0;
            ts_perf_instruction_issue <= '0;
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

            writeback_allocate <= writeback_allocate_nxt;
            ts_perf_instruction_issue <= |thread_issue_oh;
        end
    end
endmodule
